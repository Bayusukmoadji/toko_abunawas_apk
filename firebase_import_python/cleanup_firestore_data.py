from __future__ import annotations

import argparse
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


BASE_DIR = Path(__file__).resolve().parent
SERVICE_ACCOUNT_FILE = BASE_DIR / "serviceAccountKey.json"

CONFIRMATION_TEXT = "RESET-STOCK-DATA"

# Data operasional saja.
# Collection "users" sengaja dipertahankan agar akun dan role tidak hilang.
COLLECTIONS_TO_CLEAR = [
    "batch_movements",
    "transactions",
    "batches",
    "storage_locations",
    "counters",
    "products",
    "import_logs",
    "test_import",
]


def initialize_firestore():
    if not SERVICE_ACCOUNT_FILE.exists():
        raise FileNotFoundError(
            "serviceAccountKey.json tidak ditemukan:\n"
            f"{SERVICE_ACCOUNT_FILE}"
        )

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate(
                str(SERVICE_ACCOUNT_FILE)
            )
        )

    return firestore.client()


def count_documents(
    database,
    collection_name: str,
) -> int:
    return sum(
        1
        for _ in database
        .collection(collection_name)
        .stream()
    )


def delete_collection(
    database,
    collection_name: str,
    batch_size: int = 400,
) -> int:
    total_deleted = 0

    collection = database.collection(
        collection_name
    )

    while True:
        documents = list(
            collection
            .limit(batch_size)
            .stream()
        )

        if not documents:
            break

        write_batch = database.batch()

        for document in documents:
            write_batch.delete(
                document.reference
            )

        write_batch.commit()

        total_deleted += len(documents)

        print(
            f"{collection_name}: "
            f"{total_deleted} dokumen terhapus..."
        )

    return total_deleted


def print_counts(
    database,
) -> dict[str, int]:
    counts: dict[str, int] = {}

    for collection_name in COLLECTIONS_TO_CLEAR:
        counts[collection_name] = (
            count_documents(
                database,
                collection_name,
            )
        )

        print(
            f"- {collection_name}: "
            f"{counts[collection_name]} dokumen"
        )

    users_count = count_documents(
        database,
        "users",
    )

    print(
        f"- users: {users_count} dokumen "
        "(DIPERTAHANKAN)"
    )

    return counts


def verify_cleanup(
    database,
) -> None:
    remaining = {
        collection_name: count_documents(
            database,
            collection_name,
        )
        for collection_name
        in COLLECTIONS_TO_CLEAR
    }

    remaining = {
        collection_name: count
        for collection_name, count
        in remaining.items()
        if count > 0
    }

    if remaining:
        details = "\n".join(
            f"- {collection_name}: "
            f"{count} dokumen"
            for collection_name, count
            in remaining.items()
        )

        raise RuntimeError(
            "Cleanup belum tuntas. "
            "Masih ada dokumen:\n"
            f"{details}"
        )

    print()
    print("VERIFIKASI BERHASIL")
    print("===================")
    print(
        "Semua data operasional sudah kosong."
    )
    print(
        "Collection users tetap dipertahankan."
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Kosongkan data operasional Firestore "
            "sebelum import ulang Januari-Juli 2026."
        )
    )

    parser.add_argument(
        "--commit",
        action="store_true",
        help=(
            "Benar-benar menghapus data. "
            "Tanpa flag ini hanya dry run."
        ),
    )

    parser.add_argument(
        "--confirm",
        default="",
        help=(
            "Konfirmasi wajib saat commit. "
            f"Nilainya: {CONFIRMATION_TEXT}"
        ),
    )

    arguments = parser.parse_args()

    database = initialize_firestore()

    print()
    print("CLEANUP DATA OPERASIONAL FIRESTORE")
    print("==================================")
    print(
        "Collection users tidak akan dihapus."
    )
    print()

    counts = print_counts(
        database,
    )

    total_documents = sum(
        counts.values()
    )

    print()
    print(
        "Total dokumen operasional: "
        f"{total_documents}"
    )

    if not arguments.commit:
        print()
        print("DRY RUN SELESAI")
        print("================")
        print(
            "Belum ada data yang dihapus."
        )
        print(
            "Perintah untuk benar-benar "
            "menghapus data:"
        )
        print(
            "python cleanup_firestore_data.py "
            "--commit "
            f"--confirm {CONFIRMATION_TEXT}"
        )

        return

    if arguments.confirm != CONFIRMATION_TEXT:
        raise ValueError(
            "Konfirmasi salah.\n"
            "Jalankan perintah berikut:\n"
            "python cleanup_firestore_data.py "
            "--commit "
            f"--confirm {CONFIRMATION_TEXT}"
        )

    print()
    print("MULAI MENGHAPUS DATA")
    print("====================")

    total_deleted = 0

    for collection_name in COLLECTIONS_TO_CLEAR:
        total_deleted += delete_collection(
            database,
            collection_name,
        )

    print()
    print(
        "Total dokumen terhapus: "
        f"{total_deleted}"
    )

    verify_cleanup(
        database,
    )

    print()
    print(
        "Selanjutnya jalankan:"
    )
    print(
        "python import_initial_stock_2026.py "
        "--commit"
    )


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
        print("CLEANUP GAGAL")
        print("==============")
        print(error)

        sys.exit(1)