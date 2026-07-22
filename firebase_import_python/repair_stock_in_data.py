from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore


BASE_DIRECTORY = Path(__file__).resolve().parent

SERVICE_ACCOUNT_FILE = (
    BASE_DIRECTORY
    / "serviceAccountKey.json"
)

PRODUCTS_COLLECTION = "products"
COUNTERS_COLLECTION = "counters"

BMW_PRODUCT_ID = "bmw"
BMW_COUNTER_ID = "batch_sequence_bmw"

# Format kode produk historis menggunakan tanda hubung.
BMW_CANONICAL_CODE = "BR-002"

INVALID_COUNTER_IDS = [
    "batches",
]


def print_section(title: str) -> None:
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def initialize_firestore():
    if not SERVICE_ACCOUNT_FILE.exists():
        raise FileNotFoundError(
            "Service account tidak ditemukan:\n"
            f"{SERVICE_ACCOUNT_FILE}"
        )

    try:
        firebase_admin.get_app()
    except ValueError:
        credential = credentials.Certificate(
            str(SERVICE_ACCOUNT_FILE)
        )

        firebase_admin.initialize_app(
            credential
        )

    return firestore.client()


def parse_integer(
    value: Any,
    default: int = 0,
) -> int:
    if isinstance(value, bool):
        return default

    if isinstance(value, int):
        return value

    if isinstance(value, float):
        return int(value)

    try:
        return int(
            str(value or "").strip()
        )
    except (TypeError, ValueError):
        return default


def repair_bmw_product(
    database,
) -> bool:
    product_reference = (
        database
        .collection(PRODUCTS_COLLECTION)
        .document(BMW_PRODUCT_ID)
    )

    product_snapshot = product_reference.get()

    if not product_snapshot.exists:
        raise RuntimeError(
            "Produk BMW tidak ditemukan pada "
            f"products/{BMW_PRODUCT_ID}."
        )

    product_data = (
        product_snapshot.to_dict()
        or {}
    )

    current_code = str(
        product_data.get("code")
        or ""
    ).strip()

    minimum_stock = parse_integer(
        product_data.get("minimumStock"),
        default=0,
    )

    updates: dict[str, Any] = {}

    if current_code != BMW_CANONICAL_CODE:
        updates["code"] = BMW_CANONICAL_CODE

    if "minStock" not in product_data:
        updates["minStock"] = minimum_stock

    if "isDeleted" not in product_data:
        updates["isDeleted"] = False

    if not updates:
        print(
            "Produk BMW sudah sesuai."
        )

        return False

    updates["updatedAt"] = (
        firestore.SERVER_TIMESTAMP
    )

    product_reference.update(updates)

    print(
        "Produk BMW diperbarui:"
    )

    for field, value in updates.items():
        if field == "updatedAt":
            continue

        print(
            f"  - {field}: {value}"
        )

    return True


def repair_all_product_fields(
    database,
) -> int:
    product_documents = list(
        database
        .collection(PRODUCTS_COLLECTION)
        .stream()
    )

    total_updated = 0
    write_batch = database.batch()
    pending_writes = 0

    for document in product_documents:
        data = document.to_dict() or {}

        updates: dict[str, Any] = {}

        minimum_stock = parse_integer(
            data.get("minimumStock"),
            default=0,
        )

        if "minStock" not in data:
            updates["minStock"] = (
                minimum_stock
            )

        if "isDeleted" not in data:
            updates["isDeleted"] = False

        if not updates:
            continue

        updates["updatedAt"] = (
            firestore.SERVER_TIMESTAMP
        )

        write_batch.update(
            document.reference,
            updates,
        )

        total_updated += 1
        pending_writes += 1

        print(
            f"Produk dilengkapi: "
            f"{document.id}"
        )

        if pending_writes >= 400:
            write_batch.commit()

            write_batch = database.batch()
            pending_writes = 0

    if pending_writes > 0:
        write_batch.commit()

    return total_updated


def repair_bmw_counter(
    database,
) -> bool:
    counter_reference = (
        database
        .collection(COUNTERS_COLLECTION)
        .document(BMW_COUNTER_ID)
    )

    counter_snapshot = (
        counter_reference.get()
    )

    if not counter_snapshot.exists:
        print(
            "Counter BMW belum tersedia. "
            "Counter akan dibuat otomatis "
            "saat stok masuk berikutnya."
        )

        return False

    counter_data = (
        counter_snapshot.to_dict()
        or {}
    )

    product_id = str(
        counter_data.get("productId")
        or ""
    ).strip()

    last_number = parse_integer(
        counter_data.get("lastNumber"),
        default=0,
    )

    if (
        product_id == BMW_PRODUCT_ID
        and counter_data.get("productCode")
            == BMW_CANONICAL_CODE
        and counter_data.get("id")
            == BMW_COUNTER_ID
    ):
        print(
            "Counter BMW sudah sesuai."
        )

        return False

    counter_reference.set(
        {
            "id": BMW_COUNTER_ID,
            "productId": BMW_PRODUCT_ID,
            "productCode":
                BMW_CANONICAL_CODE,
            "lastNumber": last_number,
            "updatedAt":
                firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    print(
        "Counter BMW diperbarui:"
    )
    print(
        f"  - id: {BMW_COUNTER_ID}"
    )
    print(
        f"  - productId: {BMW_PRODUCT_ID}"
    )
    print(
        "  - productCode: "
        f"{BMW_CANONICAL_CODE}"
    )
    print(
        f"  - lastNumber: {last_number}"
    )

    return True


def delete_invalid_counters(
    database,
) -> int:
    total_deleted = 0

    for counter_id in INVALID_COUNTER_IDS:
        reference = (
            database
            .collection(COUNTERS_COLLECTION)
            .document(counter_id)
        )

        snapshot = reference.get()

        if not snapshot.exists:
            print(
                f"Counter tidak valid "
                f"'{counter_id}' sudah tidak ada."
            )

            continue

        reference.delete()

        total_deleted += 1

        print(
            "Counter tidak valid dihapus: "
            f"counters/{counter_id}"
        )

    return total_deleted


def verify_result(
    database,
) -> None:
    product_snapshot = (
        database
        .collection(PRODUCTS_COLLECTION)
        .document(BMW_PRODUCT_ID)
        .get()
    )

    counter_snapshot = (
        database
        .collection(COUNTERS_COLLECTION)
        .document(BMW_COUNTER_ID)
        .get()
    )

    invalid_counter_snapshot = (
        database
        .collection(COUNTERS_COLLECTION)
        .document("batches")
        .get()
    )

    product_data = (
        product_snapshot.to_dict()
        if product_snapshot.exists
        else {}
    ) or {}

    counter_data = (
        counter_snapshot.to_dict()
        if counter_snapshot.exists
        else {}
    ) or {}

    product_code = str(
        product_data.get("code")
        or ""
    ).strip()

    counter_code = str(
        counter_data.get("productCode")
        or ""
    ).strip()

    print_section(
        "HASIL VERIFIKASI"
    )

    print(
        "Kode produk BMW : "
        f"{product_code or '-'}"
    )

    print(
        "Kode counter BMW: "
        f"{counter_code or '-'}"
    )

    print(
        "Counter batches : "
        f"{'MASIH ADA' if invalid_counter_snapshot.exists else 'SUDAH DIHAPUS'}"
    )

    product_is_valid = (
        product_code
        == BMW_CANONICAL_CODE
    )

    counter_is_valid = (
        not counter_snapshot.exists
        or counter_code
        == BMW_CANONICAL_CODE
    )

    invalid_counter_removed = (
        not invalid_counter_snapshot.exists
    )

    if (
        product_is_valid
        and counter_is_valid
        and invalid_counter_removed
    ):
        print()
        print(
            "PERBAIKAN DATA BERHASIL."
        )
        print(
            "Silakan uji stok masuk kembali."
        )

        return

    raise RuntimeError(
        "Hasil verifikasi belum sesuai."
    )


def main() -> None:
    print_section(
        "PERBAIKAN DATA STOK MASUK"
    )

    database = initialize_firestore()

    print(
        "Koneksi Firebase berhasil."
    )

    print_section(
        "1. PERBAIKAN PRODUK BMW"
    )

    repair_bmw_product(database)

    print_section(
        "2. MELENGKAPI FIELD PRODUK LAMA"
    )

    total_product_updates = (
        repair_all_product_fields(
            database
        )
    )

    print(
        "Jumlah produk lama diperbarui: "
        f"{total_product_updates}"
    )

    print_section(
        "3. PERBAIKAN COUNTER BMW"
    )

    repair_bmw_counter(database)

    print_section(
        "4. MENGHAPUS COUNTER TIDAK VALID"
    )

    total_deleted = (
        delete_invalid_counters(
            database
        )
    )

    print(
        "Jumlah counter tidak valid "
        f"dihapus: {total_deleted}"
    )

    verify_result(database)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        print(
            "Proses dihentikan oleh pengguna."
        )

        raise SystemExit(130)
    except Exception as error:
        print()
        print(
            f"ERROR: {error}"
        )

        raise SystemExit(1) from error