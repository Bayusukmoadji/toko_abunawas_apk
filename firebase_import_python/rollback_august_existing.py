from __future__ import annotations

import argparse
import json
import re
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore


BASE_DIR = Path(__file__).resolve().parent
SERVICE_ACCOUNT_FILE = BASE_DIR / "serviceAccountKey.json"

YEAR = 2026
MONTH = 8

COL_PRODUCTS = "products"
COL_BATCHES = "batches"
COL_TRANSACTIONS = "transactions"
COL_COUNTERS = "counters"
COL_LOCATIONS = "storage_locations"
COL_MOVEMENTS = "batch_movements"

LOCATIONS = [
    *[f"A{i}" for i in range(1, 11)],
    *[f"B{i}" for i in range(1, 11)],
    *[f"C{i}" for i in range(1, 11)],
    *[f"D{i}" for i in range(1, 6)],
    *[f"X{i}" for i in range(1, 6)],
]

BACKUP_FILE = BASE_DIR / "backup_before_august_rollback_2026.json"


def initialize_firestore():
    if not SERVICE_ACCOUNT_FILE.exists():
        raise FileNotFoundError(
            f"serviceAccountKey.json tidak ditemukan: {SERVICE_ACCOUNT_FILE}"
        )
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate(str(SERVICE_ACCOUNT_FILE))
        )
    return firestore.client()


def load_collection(db, name: str) -> dict[str, dict[str, Any]]:
    return {
        doc.id: (doc.to_dict() or {})
        for doc in db.collection(name).stream()
    }


def as_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.replace(tzinfo=None)
    if hasattr(value, "to_datetime"):
        return value.to_datetime().replace(tzinfo=None)
    return None


def is_august(value: Any) -> bool:
    dt = as_datetime(value)
    return bool(dt and dt.year == YEAR and dt.month == MONTH)


def parse_int(value: Any) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, (int, float)):
        return int(value)
    try:
        return int(str(value or "0").strip())
    except ValueError:
        return 0


def slugify(value: Any) -> str:
    text = str(value or "").strip().lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return re.sub(r"^_+|_+$", "", text)


def counter_id(product_id: str) -> str:
    return f"batch_sequence_{slugify(product_id) or 'unknown'}"


def extract_sequence(batch_code: str) -> int:
    try:
        return int(str(batch_code or "").strip().split("-")[-1])
    except Exception:
        return 0


def location_zone(location: str) -> str:
    return "backup" if location.upper().startswith("X") else "main"


def json_default(value: Any):
    dt = as_datetime(value)
    if dt is not None:
        return dt.isoformat()
    return str(value)


def timestamp_sort_value(data: dict[str, Any]) -> datetime:
    for key in ("createdAt", "movedAt", "updatedAt"):
        dt = as_datetime(data.get(key))
        if dt is not None:
            return dt
    return datetime(1970, 1, 1)


def validate_current_integrity(
    products: dict[str, dict[str, Any]],
    batches: dict[str, dict[str, Any]],
):
    active_by_location: dict[str, str] = {}
    stock_by_product: dict[str, int] = {pid: 0 for pid in products}

    for batch_id, data in batches.items():
        status = str(data.get("status") or "").strip().lower()
        remaining = parse_int(data.get("remainingQty"))
        if status != "active" or remaining <= 0:
            continue

        product_id = str(data.get("productId") or "").strip()
        location = str(data.get("storageLocation") or "").strip().upper()

        if product_id not in products:
            raise RuntimeError(
                f"Batch aktif {batch_id} menunjuk produk yang tidak ada: {product_id}"
            )
        if location not in LOCATIONS:
            raise RuntimeError(
                f"Batch aktif {batch_id} memiliki lokasi tidak valid: {location}"
            )
        if location in active_by_location:
            raise RuntimeError(
                f"Lokasi {location} dipakai dua batch aktif: "
                f"{active_by_location[location]} dan {batch_id}"
            )

        active_by_location[location] = batch_id
        stock_by_product[product_id] += remaining

    mismatches = []
    for product_id, product in products.items():
        cached = parse_int(product.get("totalStock"))
        actual = stock_by_product.get(product_id, 0)
        if cached != actual:
            mismatches.append(
                f"{product_id}: products.totalStock={cached}, batch aktif={actual}"
            )

    if mismatches:
        raise RuntimeError(
            "State Firestore sudah tidak konsisten sebelum rollback:\n- "
            + "\n- ".join(mismatches)
        )


def build_location_documents(
    batches: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    occupied: dict[str, tuple[str, dict[str, Any]]] = {}

    for batch_id, data in batches.items():
        status = str(data.get("status") or "").strip().lower()
        remaining = parse_int(data.get("remainingQty"))
        if status != "active" or remaining <= 0:
            continue

        location = str(data.get("storageLocation") or "").strip().upper()
        if location not in LOCATIONS:
            raise RuntimeError(
                f"Batch aktif {batch_id} memiliki storageLocation tidak valid: {location}"
            )
        if location in occupied:
            raise RuntimeError(
                f"Setelah rollback ada dua batch aktif di lokasi {location}"
            )
        occupied[location] = (batch_id, data)

    result: dict[str, dict[str, Any]] = {}
    for location in LOCATIONS:
        if location not in occupied:
            result[location] = {
                "id": location,
                "location": location,
                "zone": location_zone(location),
                "isOccupied": False,
                "batchId": None,
                "batchCode": None,
                "productId": None,
                "productName": None,
                "remainingQty": 0,
                "occupiedAt": None,
                "releasedAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
            continue

        batch_id, batch = occupied[location]
        result[location] = {
            "id": location,
            "location": location,
            "zone": location_zone(location),
            "isOccupied": True,
            "batchId": batch_id,
            "batchCode": str(batch.get("batchCode") or batch_id),
            "productId": str(batch.get("productId") or ""),
            "productName": str(batch.get("productName") or ""),
            "remainingQty": parse_int(batch.get("remainingQty")),
            "occupiedAt": batch.get("createdAt") or batch.get("receivedAt"),
            "releasedAt": None,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }

    return result


def calculate_counter_targets(
    products: dict[str, dict[str, Any]],
    batches: dict[str, dict[str, Any]],
    touched_products: set[str],
) -> dict[str, dict[str, Any]]:
    max_seq: dict[str, int] = {pid: 0 for pid in products}
    for batch_id, data in batches.items():
        product_id = str(data.get("productId") or "").strip()
        if product_id not in max_seq:
            continue
        batch_code = str(data.get("batchCode") or batch_id)
        max_seq[product_id] = max(max_seq[product_id], extract_sequence(batch_code))

    result = {}
    for product_id in touched_products:
        product = products[product_id]
        doc_id = counter_id(product_id)
        result[doc_id] = {
            "id": doc_id,
            "productId": product_id,
            "productCode": str(product.get("code") or "").strip().upper(),
            "lastNumber": max_seq.get(product_id, 0),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    return result


def simulate_rollback(
    products: dict[str, dict[str, Any]],
    batches: dict[str, dict[str, Any]],
    transactions: dict[str, dict[str, Any]],
):
    target_products = deepcopy(products)
    target_batches = deepcopy(batches)

    august_transactions = {
        tx_id: data
        for tx_id, data in transactions.items()
        if is_august(data.get("createdAt"))
        and str(data.get("type") or "").strip().lower() in {"stock_in", "stock_out"}
    }

    if not august_transactions:
        raise RuntimeError("Tidak ada transaksi stock_in/stock_out Agustus untuk di-rollback.")

    ordered = sorted(
        august_transactions.items(),
        key=lambda item: timestamp_sort_value(item[1]),
        reverse=True,
    )

    touched_products: set[str] = set()
    changed_pre_august_batches: set[str] = set()
    delete_batch_ids: set[str] = set()

    reversed_in = 0
    reversed_out = 0
    qty_in = 0
    qty_out = 0

    for tx_id, tx in ordered:
        tx_type = str(tx.get("type") or "").strip().lower()
        product_id = str(tx.get("productId") or "").strip()
        batch_id = str(tx.get("batchId") or tx.get("batchCode") or "").strip()
        qty = parse_int(tx.get("qty"))

        if product_id not in target_products:
            raise RuntimeError(
                f"Transaksi {tx_id} menunjuk productId yang tidak ada: {product_id}"
            )
        if not batch_id or batch_id not in target_batches:
            raise RuntimeError(
                f"Transaksi {tx_id} menunjuk batch yang tidak ditemukan: {batch_id}"
            )
        if qty <= 0:
            raise RuntimeError(f"Qty transaksi {tx_id} tidak valid: {qty}")

        touched_products.add(product_id)
        product = target_products[product_id]
        batch = target_batches[batch_id]

        if tx_type == "stock_out":
            current_remaining = parse_int(batch.get("remainingQty"))
            initial_qty = parse_int(batch.get("initialQty"))
            restored = current_remaining + qty
            if initial_qty > 0 and restored > initial_qty:
                raise RuntimeError(
                    f"Rollback {tx_id} membuat remainingQty batch {batch_id} "
                    f"melebihi initialQty ({restored}>{initial_qty})."
                )

            batch["remainingQty"] = restored
            batch["status"] = "active" if restored > 0 else "empty"
            batch["updatedAt"] = firestore.SERVER_TIMESTAMP

            product["totalStock"] = parse_int(product.get("totalStock")) + qty
            product["updatedAt"] = firestore.SERVER_TIMESTAMP

            if not is_august(batch.get("receivedAt")):
                changed_pre_august_batches.add(batch_id)

            reversed_out += 1
            qty_out += qty
            continue

        # stock_in must be reversed only after all later stock_out transactions
        # have already been reversed (because we process newest -> oldest).
        current_remaining = parse_int(batch.get("remainingQty"))
        initial_qty = parse_int(batch.get("initialQty"))
        batch_received = batch.get("receivedAt")

        if not is_august(batch_received):
            raise RuntimeError(
                f"Stock-in Agustus {tx_id} menunjuk batch {batch_id} "
                "yang receivedAt-nya bukan Agustus. Rollback dibatalkan."
            )

        if initial_qty != qty:
            raise RuntimeError(
                f"Stock-in {tx_id}: qty transaksi={qty}, initialQty batch={initial_qty}. "
                "Tidak aman menghapus batch otomatis."
            )

        if current_remaining != initial_qty:
            raise RuntimeError(
                f"Batch Agustus {batch_id} belum kembali ke initialQty setelah "
                f"membalik stok keluar: remaining={current_remaining}, initial={initial_qty}."
            )

        new_product_stock = parse_int(product.get("totalStock")) - qty
        if new_product_stock < 0:
            raise RuntimeError(
                f"Rollback stock-in {tx_id} membuat stok produk {product_id} negatif."
            )

        product["totalStock"] = new_product_stock
        product["updatedAt"] = firestore.SERVER_TIMESTAMP

        delete_batch_ids.add(batch_id)
        del target_batches[batch_id]

        reversed_in += 1
        qty_in += qty

    # Final target integrity.
    validate_current_integrity(target_products, target_batches)

    return {
        "august_transactions": august_transactions,
        "target_products": target_products,
        "target_batches": target_batches,
        "touched_products": touched_products,
        "changed_pre_august_batches": changed_pre_august_batches,
        "delete_batch_ids": delete_batch_ids,
        "reversed_in": reversed_in,
        "reversed_out": reversed_out,
        "qty_in": qty_in,
        "qty_out": qty_out,
    }


def save_backup(
    products,
    batches,
    transactions,
    locations,
    counters,
    movements,
    august_tx_ids,
    affected_batch_ids,
    touched_products,
):
    payload = {
        "createdAt": datetime.now().isoformat(),
        "description": "Backup lokal sebelum rollback transaksi Agustus 2026",
        "transactions": {
            tx_id: transactions[tx_id]
            for tx_id in august_tx_ids
            if tx_id in transactions
        },
        "batches": {
            batch_id: batches[batch_id]
            for batch_id in affected_batch_ids
            if batch_id in batches
        },
        "products": {
            product_id: products[product_id]
            for product_id in touched_products
            if product_id in products
        },
        "storage_locations": locations,
        "counters": counters,
        "batch_movements_august": movements,
    }

    BACKUP_FILE.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False, default=json_default),
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser(
        description="Rollback aman transaksi Agustus 2026 sebelum import dataset baru."
    )
    parser.add_argument(
        "--commit",
        action="store_true",
        help="Benar-benar menulis rollback ke Firestore. Default hanya dry run.",
    )
    parser.add_argument(
        "--confirm-reset-august",
        action="store_true",
        help="Konfirmasi eksplisit bahwa transaksi Agustus saat ini memang akan dihapus.",
    )
    args = parser.parse_args()

    print("ROLLBACK TRANSAKSI AGUSTUS 2026")
    print("===============================")
    print("Mode:", "COMMIT" if args.commit else "DRY RUN")
    print("Januari-Juli tidak dihapus atau di-import ulang.")
    print()

    db = initialize_firestore()

    products = load_collection(db, COL_PRODUCTS)
    batches = load_collection(db, COL_BATCHES)
    transactions = load_collection(db, COL_TRANSACTIONS)
    locations = load_collection(db, COL_LOCATIONS)
    counters = load_collection(db, COL_COUNTERS)
    movements_all = load_collection(db, COL_MOVEMENTS)

    august_movements = {
        movement_id: data
        for movement_id, data in movements_all.items()
        if is_august(data.get("movedAt") or data.get("createdAt"))
    }

    print(
        f"Firestore: products={len(products)}, batches={len(batches)}, "
        f"transactions={len(transactions)}, locations={len(locations)}, "
        f"counters={len(counters)}"
    )
    print(f"Batch movements Agustus: {len(august_movements)}")

    if august_movements:
        print()
        print("ROLLBACK DIBATALKAN")
        print("===================")
        print(
            "Ada batch_movements pada Agustus. Script sengaja berhenti agar "
            "lokasi historis tidak dipulihkan secara keliru."
        )
        for movement_id, data in list(august_movements.items())[:20]:
            print(
                f"- {movement_id} | batch={data.get('batchId')} | "
                f"{data.get('fromLocation')} -> {data.get('toLocation')}"
            )
        return

    validate_current_integrity(products, batches)
    result = simulate_rollback(products, batches, transactions)

    august_transactions = result["august_transactions"]
    affected_batch_ids = {
        str(tx.get("batchId") or tx.get("batchCode") or "").strip()
        for tx in august_transactions.values()
    }

    print()
    print("RINGKASAN ROLLBACK YANG DIRENCANAKAN")
    print("-----------------------------------")
    print(f"Transaksi Agustus dihapus : {len(august_transactions)}")
    print(f"  stock_in dibalik        : {result['reversed_in']} docs / {result['qty_in']} qty")
    print(f"  stock_out dibalik       : {result['reversed_out']} docs / {result['qty_out']} qty")
    print(f"Batch Agustus dihapus     : {len(result['delete_batch_ids'])}")
    print(f"Batch pra-Agustus dipulih.: {len(result['changed_pre_august_batches'])}")
    print(f"Produk disesuaikan        : {len(result['touched_products'])}")

    for product_id in sorted(result["touched_products"]):
        before = parse_int(products[product_id].get("totalStock"))
        after = parse_int(result["target_products"][product_id].get("totalStock"))
        print(f"- {product_id:<24} stock {before} -> {after}")

    if not args.commit:
        print()
        print("DRY RUN BERHASIL")
        print("================")
        print("Belum ada data yang diubah.")
        print(
            "Jika ringkasan di atas benar, jalankan:\n"
            "python rollback_august_existing.py --commit --confirm-reset-august"
        )
        return

    if not args.confirm_reset_august:
        raise RuntimeError(
            "Untuk commit wajib menambahkan --confirm-reset-august"
        )

    # Re-read transaction IDs immediately before commit to avoid silently deleting
    # a newly created August transaction after the dry run.
    current_transactions = load_collection(db, COL_TRANSACTIONS)
    current_august_ids = {
        tx_id
        for tx_id, data in current_transactions.items()
        if is_august(data.get("createdAt"))
        and str(data.get("type") or "").strip().lower() in {"stock_in", "stock_out"}
    }
    expected_august_ids = set(august_transactions)
    if current_august_ids != expected_august_ids:
        raise RuntimeError(
            "Daftar transaksi Agustus berubah sejak simulasi. Commit dibatalkan. "
            "Jalankan dry run lagi."
        )

    # Save local backup before any Firestore writes.
    save_backup(
        products=products,
        batches=batches,
        transactions=transactions,
        locations=locations,
        counters=counters,
        movements=august_movements,
        august_tx_ids=expected_august_ids,
        affected_batch_ids=affected_batch_ids,
        touched_products=result["touched_products"],
    )
    print(f"\nBackup lokal dibuat: {BACKUP_FILE.name}")

    location_targets = build_location_documents(result["target_batches"])
    counter_targets = calculate_counter_targets(
        products=result["target_products"],
        batches=result["target_batches"],
        touched_products=result["touched_products"],
    )

    batch_write = db.batch()

    # Restore pre-August batches affected by August stock_out.
    for batch_id in result["changed_pre_august_batches"]:
        ref = db.collection(COL_BATCHES).document(batch_id)
        batch_write.set(
            ref,
            result["target_batches"][batch_id],
            merge=True,
        )

    # Delete batches that were created by August stock_in.
    for batch_id in result["delete_batch_ids"]:
        batch_write.delete(db.collection(COL_BATCHES).document(batch_id))

    # Restore product totals.
    for product_id in result["touched_products"]:
        target = result["target_products"][product_id]
        batch_write.set(
            db.collection(COL_PRODUCTS).document(product_id),
            {
                "totalStock": parse_int(target.get("totalStock")),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

    # Rebuild current location locks from target active batches.
    for location, value in location_targets.items():
        batch_write.set(
            db.collection(COL_LOCATIONS).document(location),
            value,
            merge=True,
        )

    # Reset only touched batch counters to max remaining batch sequence.
    for doc_id, value in counter_targets.items():
        batch_write.set(
            db.collection(COL_COUNTERS).document(doc_id),
            value,
            merge=True,
        )

    # Delete August stock transactions.
    for tx_id in expected_august_ids:
        batch_write.delete(db.collection(COL_TRANSACTIONS).document(tx_id))

    batch_write.commit()

    print()
    print("ROLLBACK COMMIT SELESAI")
    print("=======================")
    print("Memverifikasi hasil...")

    products_after = load_collection(db, COL_PRODUCTS)
    batches_after = load_collection(db, COL_BATCHES)
    transactions_after = load_collection(db, COL_TRANSACTIONS)

    validate_current_integrity(products_after, batches_after)

    remaining_august = {
        tx_id
        for tx_id, data in transactions_after.items()
        if is_august(data.get("createdAt"))
        and str(data.get("type") or "").strip().lower() in {"stock_in", "stock_out"}
    }
    if remaining_august:
        raise RuntimeError(
            "Masih ada transaksi Agustus setelah rollback: "
            + ", ".join(sorted(remaining_august)[:10])
        )

    for batch_id in result["delete_batch_ids"]:
        if batch_id in batches_after:
            raise RuntimeError(f"Batch Agustus masih ada setelah rollback: {batch_id}")

    print("✓ Tidak ada lagi transaksi stock_in/stock_out Agustus.")
    print("✓ Batch Agustus dari transaksi yang dirollback sudah dihapus.")
    print("✓ products.totalStock konsisten dengan remainingQty batch aktif.")
    print()
    print("Berikutnya jalankan:")
    print("python import_august_2026.py")
    print("untuk DRY RUN import dataset Agustus 1-31.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print()
        print("ROLLBACK GAGAL")
        print("==============")
        print(error)
        raise
