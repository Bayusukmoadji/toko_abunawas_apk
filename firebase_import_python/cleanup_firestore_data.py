from __future__ import annotations

import argparse
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


SERVICE_ACCOUNT_FILE = Path("serviceAccountKey.json")

COLLECTIONS_TO_CLEAR = [
    "products",
    "batches",
    "transactions",
    "import_logs",
    "test_import",
]


def initialize_firestore():
    if not SERVICE_ACCOUNT_FILE.exists():
        raise FileNotFoundError(
            f"Service account tidak ditemukan: {SERVICE_ACCOUNT_FILE.resolve()}"
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT_FILE))
        firebase_admin.initialize_app(cred)

    return firestore.client()


def count_documents(db, collection_name: str) -> int:
    count = 0
    for _ in db.collection(collection_name).stream():
        count += 1
    return count


def delete_collection(db, collection_name: str, batch_size: int = 450) -> int:
    total_deleted = 0

    while True:
        docs = list(db.collection(collection_name).limit(batch_size).stream())

        if not docs:
            break

        batch = db.batch()

        for doc in docs:
            batch.delete(doc.reference)

        batch.commit()

        total_deleted += len(docs)
        print(f"{collection_name}: {total_deleted} dokumen terhapus...")

    return total_deleted


def main():
    parser = argparse.ArgumentParser(
        description="Kosongkan data percobaan Firestore sebelum import data awal."
    )

    parser.add_argument(
        "--commit",
        action="store_true",
        help="Benar-benar menghapus data dari Firestore.",
    )

    args = parser.parse_args()

    db = initialize_firestore()

    print("Collection yang akan dicek/dihapus:")
    for collection_name in COLLECTIONS_TO_CLEAR:
        print(f"- {collection_name}")

    print("\nCek jumlah dokumen...")
    total_docs = 0

    for collection_name in COLLECTIONS_TO_CLEAR:
        count = count_documents(db, collection_name)
        total_docs += count
        print(f"{collection_name}: {count} dokumen")

    print(f"\nTotal dokumen ditemukan: {total_docs}")

    if not args.commit:
        print("\nDRY RUN selesai. Belum ada data yang dihapus.")
        print("Kalau sudah yakin, jalankan:")
        print("python cleanup_firestore_data.py --commit")
        return

    print("\nMulai menghapus data...")
    total_deleted = 0

    for collection_name in COLLECTIONS_TO_CLEAR:
        deleted = delete_collection(db, collection_name)
        total_deleted += deleted

    print("\nCleanup selesai.")
    print(f"Total dokumen terhapus: {total_deleted}")
    print("\nSekarang boleh jalankan import data Januari-Mei.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("\nCLEANUP GAGAL")
        print("=============")
        print(error)
        sys.exit(1)
