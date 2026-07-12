from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import firebase_admin
import openpyxl
from firebase_admin import credentials, firestore


SERVICE_ACCOUNT_FILE = Path("serviceAccountKey.json")

EXCEL_FILES = [
    Path("data_stok_beras_2026_01_januari.xlsx"),
    Path("data_stok_beras_2026_02_februari.xlsx"),
    Path("data_stok_beras_2026_03_maret.xlsx"),
    Path("data_stok_beras_2026_04_april.xlsx"),
    Path("data_stok_beras_2026_05_mei.xlsx"),
    Path("data_stok_beras_2026_06_juni.xlsx"),
]

PREFERRED_SHEET_NAME = "Data Stok"

COLLECTION_PRODUCTS = "products"
COLLECTION_BATCHES = "batches"
COLLECTION_TRANSACTIONS = "transactions"
COLLECTION_IMPORT_LOGS = "import_logs"

IMPORT_LOG_ID = "initial_stock_jan_jun_2026"

DEFAULT_CATEGORY = "Beras"
DEFAULT_MINIMUM_STOCK = 25
IMPORT_USER_ID = "initial_import"
IMPORT_USER_NAME = "Import Data Awal"

STACK_LOCATIONS = [
    *[f"A{i}" for i in range(1, 11)],
    *[f"B{i}" for i in range(1, 11)],
    *[f"C{i}" for i in range(1, 11)],
    *[f"D{i}" for i in range(1, 6)],
]

PRODUCT_CODE_BY_NAME = {
    "beras_walet": "BR-001",
    "bmw": "BR-002",
    "cap_kembang": "BR-003",
    "ir_cap_mercy": "BR-004",
    "karya_makmur": "BR-005",
    "keraton": "BR-006",
    "pandan_wangi": "BR-007",
    "ramos": "BR-008",
    "rojo_lele": "BR-009",
    "sumber_raya": "BR-010",
}


@dataclass
class ImportRow:
    source_file: str
    source_order: int
    original_index: int
    row_key: str
    tanggal: datetime
    date_key: str
    product_id: str
    product_name: str
    product_code: str
    stock_in: int
    stock_out: int
    unit: str
    notes: str


@dataclass
class FifoBatch:
    id: str
    batch_code: str
    remaining_qty: int
    received_at: datetime
    storage_location: str


def normalize_header(value: Any) -> str:
    text = str(value or "").strip().lower()
    return re.sub(r"[^a-z0-9]+", "", text)


def slugify(value: Any) -> str:
    text = str(value or "").strip().lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = re.sub(r"^_+|_+$", "", text)
    return text


def to_title_case(value: Any) -> str:
    text = str(value or "").strip()
    words = [word for word in text.split(" ") if word]
    result = []

    for word in words:
        if word.isupper() and len(word) <= 5:
            result.append(word)
        else:
            result.append(word[:1].upper() + word[1:].lower())

    return " ".join(result)


def pad2(value: int) -> str:
    return str(value).zfill(2)


def pad3(value: int) -> str:
    return str(value).zfill(3)


def format_date_key(date: datetime) -> str:
    return f"{date.year}{pad2(date.month)}{pad2(date.day)}"


def format_display_date(date: datetime) -> str:
    return f"{pad2(date.day)}/{pad2(date.month)}/{date.year}"


def with_time(date: datetime, hour: int, minute: int = 0) -> datetime:
    return datetime(date.year, date.month, date.day, hour, minute, 0)


def parse_number(value: Any) -> int:
    if value is None or value == "":
        return 0

    if isinstance(value, int):
        return value

    if isinstance(value, float):
        return round(value)

    text = str(value).strip()

    if not text:
        return 0

    text = text.replace(" ", "").replace(".", "").replace(",", ".")

    try:
        return round(float(text))
    except ValueError:
        return 0


def parse_excel_date(value: Any) -> datetime:
    if isinstance(value, datetime):
        return datetime(value.year, value.month, value.day)

    if isinstance(value, int) or isinstance(value, float):
        parsed = datetime(1899, 12, 30) + timedelta(days=int(value))
        return datetime(parsed.year, parsed.month, parsed.day)

    text = str(value or "").strip()

    if not text:
        raise ValueError("Tanggal kosong.")

    for fmt in ("%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d %m %Y"):
        try:
            parsed = datetime.strptime(text, fmt)
            return datetime(parsed.year, parsed.month, parsed.day)
        except ValueError:
            pass

    parsed = datetime.fromisoformat(text)
    return datetime(parsed.year, parsed.month, parsed.day)


def get_sheet(workbook):
    if PREFERRED_SHEET_NAME in workbook.sheetnames:
        return workbook[PREFERRED_SHEET_NAME]

    return workbook[workbook.sheetnames[0]]


def build_header_index(sheet) -> dict[str, int]:
    raw_headers = [cell.value for cell in sheet[1]]
    normalized_headers = [normalize_header(value) for value in raw_headers]

    aliases = {
        "tanggal": ["tanggal", "date", "tgl"],
        "product": [
            "merkjenisberas",
            "merkberas",
            "jenisberas",
            "produk",
            "namaproduk",
            "barang",
        ],
        "stock_in": [
            "stokmasuk",
            "stockin",
            "masuk",
            "qtymasuk",
            "jumlahmasuk",
        ],
        "stock_out": [
            "stokkeluar",
            "stockout",
            "keluar",
            "qtykeluar",
            "jumlahkeluar",
        ],
        "unit": ["satuan", "unit"],
        "notes": ["catatan", "notes", "keterangan"],
    }

    result: dict[str, int] = {}

    for key, possible_names in aliases.items():
        for possible_name in possible_names:
            if possible_name in normalized_headers:
                result[key] = normalized_headers.index(possible_name)
                break

    required_keys = ["tanggal", "product", "stock_in", "stock_out"]

    missing = [key for key in required_keys if key not in result]

    if missing:
        readable_headers = [str(value or "").strip() for value in raw_headers]
        raise ValueError(
            "Kolom wajib tidak ditemukan. "
            f"Missing: {missing}. Header terbaca: {readable_headers}"
        )

    return result


def get_product_code(product_id: str, fallback_number: int) -> str:
    if product_id in PRODUCT_CODE_BY_NAME:
        return PRODUCT_CODE_BY_NAME[product_id]

    return f"BR-{pad3(fallback_number)}"


def read_excel_file(file_path: Path, source_order: int) -> list[ImportRow]:
    if not file_path.exists():
        raise FileNotFoundError(f"File tidak ditemukan: {file_path}")

    workbook = openpyxl.load_workbook(file_path, data_only=True)
    sheet = get_sheet(workbook)
    header_index = build_header_index(sheet)

    rows: list[ImportRow] = []
    source_slug = slugify(file_path.stem)

    fallback_code_counter = 11
    fallback_codes: dict[str, str] = {}

    for row_index, row in enumerate(
        sheet.iter_rows(min_row=2, values_only=True),
        start=2,
    ):
        tanggal_raw = row[header_index["tanggal"]]
        product_raw = row[header_index["product"]]
        stock_in_raw = row[header_index["stock_in"]]
        stock_out_raw = row[header_index["stock_out"]]

        unit_raw = row[header_index["unit"]] if "unit" in header_index else "Karung"
        notes_raw = row[header_index["notes"]] if "notes" in header_index else ""

        if tanggal_raw is None and product_raw is None:
            continue

        tanggal = parse_excel_date(tanggal_raw)
        product_name = to_title_case(product_raw)
        product_id = slugify(product_raw)

        if not product_id:
            raise ValueError(f"{file_path.name} baris {row_index}: nama beras kosong.")

        if product_id in PRODUCT_CODE_BY_NAME:
            product_code = PRODUCT_CODE_BY_NAME[product_id]
        else:
            if product_id not in fallback_codes:
                fallback_codes[product_id] = f"BR-{pad3(fallback_code_counter)}"
                fallback_code_counter += 1
            product_code = fallback_codes[product_id]

        stock_in = parse_number(stock_in_raw)
        stock_out = parse_number(stock_out_raw)

        if stock_in <= 0 and stock_out <= 0:
            continue

        unit = str(unit_raw or "Karung").strip()
        notes = str(notes_raw or "").strip()


        date_key = format_date_key(tanggal)
        row_key = f"{source_slug}_{row_index}"

        rows.append(
            ImportRow(
                source_file=file_path.name,
                source_order=source_order,
                original_index=row_index,
                row_key=row_key,
                tanggal=tanggal,
                date_key=date_key,
                product_id=product_id,
                product_name=product_name,
                product_code=product_code,
                stock_in=stock_in,
                stock_out=stock_out,
                unit=unit,
                notes=notes,
            )
        )

    return rows


def read_all_excel_rows() -> list[ImportRow]:
    all_rows: list[ImportRow] = []

    for index, file_path in enumerate(EXCEL_FILES, start=1):
        print(f"Membaca {file_path.name}...")
        rows = read_excel_file(file_path, source_order=index)
        print(f"  {len(rows)} baris valid.")
        all_rows.extend(rows)

    all_rows.sort(
        key=lambda item: (
            item.tanggal,
            item.source_order,
            item.original_index,
        )
    )

    return all_rows


def initialize_firestore():
    if not SERVICE_ACCOUNT_FILE.exists():
        raise FileNotFoundError(
            f"Service account tidak ditemukan: {SERVICE_ACCOUNT_FILE.resolve()}"
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT_FILE))
        firebase_admin.initialize_app(cred)

    return firestore.client()



def get_available_location(
    available_locations: list[str],
    occupied_locations: dict[str, str],
    batch_code: str,
) -> str:
    if not available_locations:
        active_locations = ", ".join(sorted(occupied_locations.keys()))
        raise ValueError(
            "Kapasitas tumpukan tidak cukup untuk membuat batch baru.\n"
            f"Batch yang akan dibuat: {batch_code}\n"
            f"Total tumpukan tersedia: {len(STACK_LOCATIONS)}\n"
            f"Tumpukan aktif: {active_locations}"
        )

    return available_locations.pop(0)


def release_location(
    storage_location: str,
    available_locations: list[str],
    occupied_locations: dict[str, str],
) -> None:
    if not storage_location:
        return

    occupied_locations.pop(storage_location, None)

    if storage_location not in available_locations:
        available_locations.append(storage_location)
        available_locations.sort(key=lambda item: STACK_LOCATIONS.index(item))


def build_firestore_data(rows: list[ImportRow]):
    product_map: dict[str, dict[str, Any]] = {}
    fifo_queues: dict[str, list[FifoBatch]] = {}
    batch_seq_map: dict[str, int] = {}

    batch_map: dict[str, dict[str, Any]] = {}
    transaction_map: dict[str, dict[str, Any]] = {}

    available_locations = list(STACK_LOCATIONS)
    occupied_locations: dict[str, str] = {}
    used_locations: set[str] = set()

    stock_in_transaction_count = 0
    stock_out_transaction_count = 0

    for row in rows:
        if row.product_id not in product_map:
            fifo_queues[row.product_id] = []
            batch_seq_map[row.product_id] = 0

            product_map[row.product_id] = {
                "id": row.product_id,
                "name": row.product_name,
                "code": row.product_code,
                "category": DEFAULT_CATEGORY,
                "unit": row.unit,
                "minimumStock": DEFAULT_MINIMUM_STOCK,
                "totalStock": 0,
                "isActive": True,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }

        if row.stock_in > 0:
            next_seq = batch_seq_map[row.product_id] + 1
            batch_seq_map[row.product_id] = next_seq

            batch_code = f"BATCH-{row.date_key}-{row.product_code}-{pad3(next_seq)}"
            batch_id = batch_code
            storage_location = get_available_location(
                available_locations=available_locations,
                occupied_locations=occupied_locations,
                batch_code=batch_code,
            )
            occupied_locations[storage_location] = batch_id
            used_locations.add(storage_location)

            batch_data = {
                "id": batch_id,
                "productId": row.product_id,
                "productName": row.product_name,
                "batchCode": batch_code,
                "receivedAt": with_time(row.tanggal, 8, 0),
                "initialQty": row.stock_in,
                "remainingQty": row.stock_in,
                "unit": row.unit,
                "qrCodeValue": batch_code,
                "status": "active",
                "storageLocation": storage_location,
                "createdBy": IMPORT_USER_ID,
                "createdByName": IMPORT_USER_NAME,
                "notes": (
                    f"Import data awal dari {row.source_file}, "
                    f"tanggal {format_display_date(row.tanggal)}. {row.notes}"
                ).strip(),
                "createdAt": with_time(row.tanggal, 8, 0),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }

            batch_map[batch_id] = batch_data

            fifo_queues[row.product_id].append(
                FifoBatch(
                    id=batch_id,
                    batch_code=batch_code,
                    remaining_qty=row.stock_in,
                    received_at=row.tanggal,
                    storage_location=storage_location,
                )
            )

            tx_id = f"tx_in_{row.row_key}_{batch_code}"

            transaction_map[tx_id] = {
                "id": tx_id,
                "type": "stock_in",
                "productId": row.product_id,
                "productName": row.product_name,
                "batchId": batch_id,
                "batchCode": batch_code,
                "qty": row.stock_in,
                "unit": row.unit,
                "performedBy": IMPORT_USER_ID,
                "performedByName": IMPORT_USER_NAME,
                "notes": (
                    f"Import stok masuk dari {row.source_file}, "
                    f"tanggal {format_display_date(row.tanggal)}. {row.notes}"
                ).strip(),
                "createdAt": with_time(row.tanggal, 8, 10),
            }

            stock_in_transaction_count += 1

        if row.stock_out > 0:
            remaining_to_out = row.stock_out
            part_index = 1
            queue = fifo_queues[row.product_id]

            while remaining_to_out > 0:
                current_batch = None

                for candidate in queue:
                    if candidate.remaining_qty > 0:
                        current_batch = candidate
                        break

                if current_batch is None:
                    raise ValueError(
                        f"Stok keluar melebihi stok tersedia.\n"
                        f"File       : {row.source_file}\n"
                        f"Baris      : {row.original_index}\n"
                        f"Tanggal    : {format_display_date(row.tanggal)}\n"
                        f"Produk     : {row.product_name}\n"
                        f"Kurang     : {remaining_to_out} {row.unit}"
                    )

                allocated_qty = min(remaining_to_out, current_batch.remaining_qty)
                current_batch.remaining_qty -= allocated_qty
                remaining_to_out -= allocated_qty

                batch_data = batch_map.get(current_batch.id)

                if batch_data is None:
                    raise ValueError(
                        f"Batch {current_batch.id} tidak ditemukan saat alokasi FIFO."
                    )

                batch_data["remainingQty"] = current_batch.remaining_qty
                batch_data["status"] = "empty" if current_batch.remaining_qty <= 0 else "active"
                batch_data["updatedAt"] = firestore.SERVER_TIMESTAMP

                if current_batch.remaining_qty <= 0:
                    release_location(
                        storage_location=current_batch.storage_location,
                        available_locations=available_locations,
                        occupied_locations=occupied_locations,
                    )

                tx_id = (
                    f"tx_out_{row.row_key}_{pad3(part_index)}_{current_batch.batch_code}"
                )

                transaction_map[tx_id] = {
                    "id": tx_id,
                    "type": "stock_out",
                    "productId": row.product_id,
                    "productName": row.product_name,
                    "batchId": current_batch.id,
                    "batchCode": current_batch.batch_code,
                    "qty": allocated_qty,
                    "unit": row.unit,
                    "performedBy": IMPORT_USER_ID,
                    "performedByName": IMPORT_USER_NAME,
                    "notes": (
                        f"Import stok keluar dari {row.source_file}, "
                        f"tanggal {format_display_date(row.tanggal)}. {row.notes}"
                    ).strip(),
                    "createdAt": with_time(row.tanggal, 15, min(part_index, 59)),
                }

                stock_out_transaction_count += 1
                part_index += 1

    for product_id, product in product_map.items():
        total_stock = 0

        for batch_data in batch_map.values():
            if batch_data["productId"] == product_id:
                total_stock += max(0, int(batch_data["remainingQty"]))

        product["totalStock"] = total_stock
        product["updatedAt"] = firestore.SERVER_TIMESTAMP

    summary = {
        "rows_processed": len(rows),
        "products_count": len(product_map),
        "batches_count": len(batch_map),
        "stock_in_transaction_count": stock_in_transaction_count,
        "stock_out_transaction_count": stock_out_transaction_count,
        "total_stock_in": sum(row.stock_in for row in rows),
        "total_stock_out": sum(row.stock_out for row in rows),
        "final_stock": sum(product["totalStock"] for product in product_map.values()),
        "total_stack_locations": len(STACK_LOCATIONS),
        "used_stack_locations_count": len(used_locations),
        "active_stack_locations_count": len(occupied_locations),
        "empty_stack_locations_count": len(available_locations),
        "active_stack_locations": sorted(occupied_locations.keys(), key=lambda item: STACK_LOCATIONS.index(item)),
        "products": product_map,
        "batches": batch_map,
        "transactions": transaction_map,
    }

    return summary


def print_summary(summary: dict[str, Any]) -> None:
    print("\nRingkasan Import")
    print("================")
    print(f"Jumlah baris Excel diproses : {summary['rows_processed']}")
    print(f"Jumlah produk               : {summary['products_count']}")
    print(f"Jumlah batch dibuat          : {summary['batches_count']}")
    print(f"Transaksi stock_in           : {summary['stock_in_transaction_count']}")
    print(f"Transaksi stock_out          : {summary['stock_out_transaction_count']}")
    print(f"Total stok masuk             : {summary['total_stock_in']}")
    print(f"Total stok keluar            : {summary['total_stock_out']}")
    print(f"Sisa stok akhir              : {summary['final_stock']}")
    print(f"Total tumpukan tersedia      : {summary['total_stack_locations']}")
    print(f"Tumpukan pernah dipakai      : {summary['used_stack_locations_count']}")
    print(f"Tumpukan aktif akhir         : {summary['active_stack_locations_count']}")
    print(f"Tumpukan kosong akhir        : {summary['empty_stack_locations_count']}")
    print(f"Lokasi aktif akhir           : {', '.join(summary['active_stack_locations']) if summary['active_stack_locations'] else '-'}")

    print("\nProduk")
    print("======")

    for product in sorted(summary["products"].values(), key=lambda item: item["code"]):
        print(
            f"{product['code']} | {product['name']} | "
            f"stok akhir: {product['totalStock']} {product['unit']}"
        )


def check_import_log(db, force: bool) -> None:
    log_ref = db.collection(COLLECTION_IMPORT_LOGS).document(IMPORT_LOG_ID)
    log_snapshot = log_ref.get()

    if log_snapshot.exists and not force:
        print("\nIMPORT DIBATALKAN")
        print("=================")
        print("Data awal Januari-Juni 2026 sudah pernah di-import.")
        print("Script dihentikan agar data tidak tertimpa saat aplikasi sudah berjalan.")
        print("\nKalau benar-benar ingin menimpa import lama, jalankan:")
        print("python import_initial_stock_2026.py --commit --force")
        sys.exit(0)


def add_write(
    writes: list[tuple[Any, dict[str, Any]]],
    db,
    collection: str,
    doc_id: str,
    data: dict[str, Any],
) -> None:
    ref = db.collection(collection).document(doc_id)
    writes.append((ref, data))


def commit_writes(db, summary: dict[str, Any]) -> None:
    writes: list[tuple[Any, dict[str, Any]]] = []

    for product_id, product in summary["products"].items():
        add_write(writes, db, COLLECTION_PRODUCTS, product_id, product)

    for batch_id, batch_data in summary["batches"].items():
        add_write(writes, db, COLLECTION_BATCHES, batch_id, batch_data)

    for transaction_id, transaction in summary["transactions"].items():
        add_write(writes, db, COLLECTION_TRANSACTIONS, transaction_id, transaction)

    print(f"\nTotal write ke Firestore: {len(writes)}")
    chunk_size = 450

    for start in range(0, len(writes), chunk_size):
        chunk = writes[start : start + chunk_size]
        batch = db.batch()

        for ref, data in chunk:
            batch.set(ref, data, merge=True)

        batch.commit()
        print(f"Commit {start + 1} - {start + len(chunk)} selesai.")


def write_import_log(db, summary: dict[str, Any]) -> None:
    db.collection(COLLECTION_IMPORT_LOGS).document(IMPORT_LOG_ID).set(
        {
            "id": IMPORT_LOG_ID,
            "description": "Import data awal stok beras Januari-Juni 2026",
            "rowsProcessed": summary["rows_processed"],
            "productsCount": summary["products_count"],
            "batchesCount": summary["batches_count"],
            "stockInTransactionCount": summary["stock_in_transaction_count"],
            "stockOutTransactionCount": summary["stock_out_transaction_count"],
            "totalStockIn": summary["total_stock_in"],
            "totalStockOut": summary["total_stock_out"],
            "finalStock": summary["final_stock"],
            "totalStackLocations": summary["total_stack_locations"],
            "usedStackLocationsCount": summary["used_stack_locations_count"],
            "activeStackLocationsCount": summary["active_stack_locations_count"],
            "emptyStackLocationsCount": summary["empty_stack_locations_count"],
            "activeStackLocations": summary["active_stack_locations"],
            "createdAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import data stok awal realistis Januari-Juni 2026 ke Cloud Firestore. Lokasi batch historis dikosongkan karena belum dicatat sebelum aplikasi diterapkan."
    )

    parser.add_argument(
        "--commit",
        action="store_true",
        help="Benar-benar insert data ke Firestore.",
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Paksa import walaupun import log sudah ada.",
    )

    args = parser.parse_args()

    print("Mode:", "COMMIT KE FIRESTORE" if args.commit else "DRY RUN / CEK DATA SAJA")

    db = initialize_firestore()

    if args.commit:
        check_import_log(db, force=args.force)

    rows = read_all_excel_rows()
    summary = build_firestore_data(rows)

    print_summary(summary)

    if not args.commit:
        print("\nDRY RUN selesai. Belum ada data yang dimasukkan ke Firebase.")
        print("Kalau ringkasan sudah benar, jalankan:")
        print("python import_initial_stock_2026.py --commit")
        return

    print("\nMulai insert data ke Firestore...")
    commit_writes(db, summary)
    write_import_log(db, summary)

    print("\nImport selesai.")
    print("Silakan cek Firebase Console pada collection:")
    print(f"- {COLLECTION_PRODUCTS}")
    print(f"- {COLLECTION_BATCHES}")
    print(f"- {COLLECTION_TRANSACTIONS}")
    print(f"- {COLLECTION_IMPORT_LOGS}/{IMPORT_LOG_ID}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("\nIMPORT GAGAL")
        print("============")
        print(error)
        sys.exit(1)
