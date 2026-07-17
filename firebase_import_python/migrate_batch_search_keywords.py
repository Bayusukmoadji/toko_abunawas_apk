from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

import firebase_admin
from firebase_admin import credentials, firestore


SERVICE_ACCOUNT_FILE = (
    Path(__file__).resolve().parent
    / "serviceAccountKey.json"
)

FIRESTORE_COLLECTION = "batches"

# Firestore mendukung maksimum 500 operasi per batch.
# Digunakan 200 agar ukuran payload tetap aman.
WRITE_BATCH_LIMIT = 200

REQUEST_TIMEOUT_SECONDS = 30

MAX_PREFIX_LENGTH = 24
MAX_KEYWORD_LENGTH = 250
MAX_NOTES_WORDS = 30
MAX_DISPLAYED_ERRORS = 10


def print_status(message: str = "") -> None:
    print(
        message,
        flush=True,
    )


def normalize_search_text(value: Any) -> str:
    text = str(value or "").strip().lower()

    text = re.sub(
        r"[^a-z0-9]+",
        " ",
        text,
    )

    text = re.sub(
        r"\s+",
        " ",
        text,
    )

    return text.strip()


def parse_integer(value: Any) -> int:
    if isinstance(value, bool):
        return 0

    if isinstance(value, (int, float)):
        return int(value)

    try:
        return int(
            str(value or "").strip()
        )
    except (TypeError, ValueError):
        return 0


def parse_datetime(
    value: Any,
) -> Optional[datetime]:
    if isinstance(value, datetime):
        return value

    return None


def add_keyword(
    keywords: set[str],
    value: Any,
) -> None:
    normalized = normalize_search_text(value)

    if not normalized:
        return

    if len(normalized) > MAX_KEYWORD_LENGTH:
        return

    keywords.add(normalized)


def add_search_value(
    keywords: set[str],
    value: Any,
    *,
    include_whole_value: bool = True,
    include_compact_value: bool = True,
    include_prefixes: bool = True,
    maximum_words: int = 30,
) -> None:
    normalized = normalize_search_text(value)

    if not normalized:
        return

    words = [
        word
        for word in normalized.split(" ")
        if word
    ][:maximum_words]

    if include_whole_value:
        add_keyword(
            keywords,
            normalized,
        )

    if include_compact_value:
        compact_value = normalized.replace(
            " ",
            "",
        )

        if len(compact_value) >= 2:
            add_keyword(
                keywords,
                compact_value,
            )

    for word in words:
        add_keyword(
            keywords,
            word,
        )

        if not include_prefixes:
            continue

        if len(word) < 2:
            continue

        maximum_prefix_length = min(
            len(word),
            MAX_PREFIX_LENGTH,
        )

        for prefix_length in range(
            2,
            maximum_prefix_length + 1,
        ):
            add_keyword(
                keywords,
                word[:prefix_length],
            )


def get_indonesian_month_name(
    month: int,
) -> str:
    month_names = [
        "januari",
        "februari",
        "maret",
        "april",
        "mei",
        "juni",
        "juli",
        "agustus",
        "september",
        "oktober",
        "november",
        "desember",
    ]

    if month < 1 or month > 12:
        return ""

    return month_names[month - 1]


def add_status_keywords(
    keywords: set[str],
    status: Any,
    remaining_qty: int,
) -> None:
    normalized_status = normalize_search_text(
        status
    )

    if (
        normalized_status == "active"
        and remaining_qty > 0
    ):
        status_values = [
            "active",
            "aktif",
            "batch aktif",
        ]

        for value in status_values:
            add_search_value(
                keywords,
                value,
            )

        return

    if (
        normalized_status
        in {
            "empty",
            "depleted",
            "inactive",
        }
        or remaining_qty <= 0
    ):
        status_values = [
            "empty",
            "depleted",
            "inactive",
            "habis",
            "tidak aktif",
            "batch habis",
        ]

        for value in status_values:
            add_search_value(
                keywords,
                value,
            )

        return

    add_search_value(
        keywords,
        normalized_status,
    )


def add_received_date_keywords(
    keywords: set[str],
    received_at: Optional[datetime],
) -> None:
    if received_at is None:
        return

    day = received_at.day
    month = received_at.month
    year = received_at.year

    # Perbaikan utama:
    # Python menggunakan zfill(), bukan pad_left().
    day_text = str(day).zfill(2)
    month_text = str(month).zfill(2)

    month_name = get_indonesian_month_name(
        month
    )

    date_values = [
        f"{day_text}/{month_text}/{year}",
        f"{day_text}-{month_text}-{year}",
        f"{year}-{month_text}-{day_text}",
        f"{year}/{month_text}/{day_text}",
        f"{day} {month_name} {year}",
        f"{day_text} {month_name} {year}",
        month_name,
        str(year),
    ]

    for value in date_values:
        add_search_value(
            keywords,
            value,
        )


def build_search_keywords(
    document_id: str,
    data: dict[str, Any],
) -> list[str]:
    keywords: set[str] = set()

    batch_id = str(
        data.get("id")
        or document_id
    ).strip()

    batch_code = str(
        data.get("batchCode")
        or document_id
    ).strip()

    qr_code_value = str(
        data.get("qrCodeValue")
        or batch_code
    ).strip()

    product_id = str(
        data.get("productId")
        or ""
    ).strip()

    product_name = str(
        data.get("productName")
        or ""
    ).strip()

    product_code = str(
        data.get("productCode")
        or ""
    ).strip()

    storage_location = str(
        data.get("storageLocation")
        or ""
    ).strip()

    created_by = str(
        data.get("createdBy")
        or ""
    ).strip()

    created_by_name = str(
        data.get("createdByName")
        or ""
    ).strip()

    unit = str(
        data.get("unit")
        or "karung"
    ).strip()

    status = str(
        data.get("status")
        or ""
    ).strip()

    notes = str(
        data.get("notes")
        or ""
    ).strip()

    initial_qty = parse_integer(
        data.get("initialQty")
    )

    remaining_qty = parse_integer(
        data.get("remainingQty")
    )

    received_at = parse_datetime(
        data.get("receivedAt")
    )

    main_values = [
        batch_id,
        batch_code,
        qr_code_value,
        product_id,
        product_name,
        product_code,
        storage_location,
        created_by,
        created_by_name,
        unit,
        initial_qty,
        remaining_qty,
        f"{initial_qty} {unit}",
        f"{remaining_qty} {unit}",
        (
            f"{remaining_qty} dari "
            f"{initial_qty} {unit}"
        ),
    ]

    for value in main_values:
        add_search_value(
            keywords,
            value,
        )

    add_status_keywords(
        keywords,
        status,
        remaining_qty,
    )

    add_received_date_keywords(
        keywords,
        received_at,
    )

    add_search_value(
        keywords,
        notes,
        include_whole_value=True,
        include_compact_value=False,
        include_prefixes=True,
        maximum_words=MAX_NOTES_WORDS,
    )

    return sorted(
        keyword
        for keyword in keywords
        if (
            keyword
            and len(keyword)
            <= MAX_KEYWORD_LENGTH
        )
    )


def normalize_existing_keywords(
    value: Any,
) -> list[str]:
    if not isinstance(value, list):
        return []

    normalized_keywords: set[str] = set()

    for keyword in value:
        normalized = normalize_search_text(
            keyword
        )

        if normalized:
            normalized_keywords.add(
                normalized
            )

    return sorted(normalized_keywords)


def initialize_firestore():
    print_status(
        "[1/4] Memeriksa service account..."
    )

    if not SERVICE_ACCOUNT_FILE.exists():
        raise FileNotFoundError(
            "File serviceAccountKey.json "
            "tidak ditemukan di:\n"
            f"{SERVICE_ACCOUNT_FILE}"
        )

    try:
        firebase_admin.get_app()

        print_status(
            "[2/4] Firebase Admin sudah aktif."
        )
    except ValueError:
        print_status(
            "[2/4] Menginisialisasi Firebase Admin..."
        )

        certificate = credentials.Certificate(
            str(SERVICE_ACCOUNT_FILE)
        )

        firebase_admin.initialize_app(
            certificate
        )

    print_status(
        "[3/4] Membuat koneksi Firestore..."
    )

    database = firestore.client()

    print_status(
        "[4/4] Koneksi Firestore siap."
    )

    return database


def commit_batch(
    write_batch: Any,
    pending_writes: int,
) -> None:
    if pending_writes <= 0:
        return

    print_status(
        f"Menyimpan {pending_writes} perubahan..."
    )

    try:
        write_batch.commit(
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
    except TypeError:
        # Kompatibilitas untuk versi lama
        # google-cloud-firestore yang belum
        # menerima parameter timeout.
        write_batch.commit()

    print_status(
        "Perubahan berhasil disimpan."
    )


def migrate_search_keywords(
    *,
    apply_changes: bool,
    maximum_documents: Optional[int],
) -> None:
    database = initialize_firestore()

    print_status()
    print_status(
        "Menyiapkan query batch..."
    )

    query = database.collection(
        FIRESTORE_COLLECTION
    )

    if maximum_documents is not None:
        query = query.limit(
            maximum_documents
        )

        print_status(
            "Batas query Firestore: "
            f"{maximum_documents} dokumen."
        )
    else:
        print_status(
            "Query akan membaca seluruh dokumen batch."
        )

    print_status(
        "Mengambil data dari Firestore..."
    )

    print_status(
        "Batas waktu koneksi: "
        f"{REQUEST_TIMEOUT_SECONDS} detik."
    )

    print_status()

    total_documents = 0
    changed_documents = 0
    skipped_documents = 0
    failed_documents = 0
    pending_writes = 0

    errors: list[str] = []

    write_batch = (
        database.batch()
        if apply_changes
        else None
    )

    try:
        document_stream = query.stream(
            timeout=REQUEST_TIMEOUT_SECONDS,
        )

        for document in document_stream:
            total_documents += 1

            print_status(
                f"[{total_documents}] "
                f"Memproses {document.id}..."
            )

            try:
                data = document.to_dict() or {}

                new_keywords = (
                    build_search_keywords(
                        document.id,
                        data,
                    )
                )

                if not new_keywords:
                    raise ValueError(
                        "searchKeywords kosong."
                    )

                existing_keywords = (
                    normalize_existing_keywords(
                        data.get(
                            "searchKeywords"
                        )
                    )
                )

                if existing_keywords == new_keywords:
                    skipped_documents += 1

                    print_status(
                        "    LEWATI — sudah sesuai "
                        f"({len(new_keywords)} keyword)"
                    )

                    continue

                if apply_changes:
                    if write_batch is None:
                        raise RuntimeError(
                            "Write batch belum tersedia."
                        )

                    write_batch.update(
                        document.reference,
                        {
                            "searchKeywords":
                                new_keywords,
                        },
                    )

                    pending_writes += 1

                changed_documents += 1

                print_status(
                    "    UPDATE — "
                    f"{len(new_keywords)} keyword"
                )

                if (
                    apply_changes
                    and pending_writes
                    >= WRITE_BATCH_LIMIT
                ):
                    if write_batch is None:
                        raise RuntimeError(
                            "Write batch belum tersedia."
                        )

                    commit_batch(
                        write_batch,
                        pending_writes,
                    )

                    write_batch = database.batch()
                    pending_writes = 0

            except Exception as error:
                failed_documents += 1

                error_message = (
                    f"{document.id}: {error}"
                )

                errors.append(error_message)

                print_status(
                    f"    GAGAL — {error}"
                )

    except Exception as error:
        print_status()
        print_status(
            "Gagal mengambil data dari Firestore."
        )

        raise RuntimeError(
            "Koneksi atau query Firestore gagal: "
            f"{error}"
        ) from error

    if (
        apply_changes
        and write_batch is not None
        and pending_writes > 0
    ):
        commit_batch(
            write_batch,
            pending_writes,
        )

    print_status()
    print_status("=" * 60)
    print_status(
        "HASIL MIGRASI SEARCH KEYWORDS"
    )
    print_status("=" * 60)

    mode = (
        "APPLY"
        if apply_changes
        else "DRY RUN"
    )

    print_status(
        f"Mode                  : {mode}"
    )

    print_status(
        "Total batch diperiksa : "
        f"{total_documents}"
    )

    print_status(
        "Perlu diperbarui      : "
        f"{changed_documents}"
    )

    print_status(
        "Sudah sesuai          : "
        f"{skipped_documents}"
    )

    print_status(
        "Gagal diproses        : "
        f"{failed_documents}"
    )

    if errors:
        print_status()
        print_status(
            "CONTOH KESALAHAN"
        )
        print_status("-" * 60)

        for error_message in errors[
            :MAX_DISPLAYED_ERRORS
        ]:
            print_status(
                f"- {error_message}"
            )

        remaining_errors = (
            len(errors)
            - MAX_DISPLAYED_ERRORS
        )

        if remaining_errors > 0:
            print_status(
                "- dan "
                f"{remaining_errors} kesalahan lainnya."
            )

    if not apply_changes:
        print_status()
        print_status(
            "Dry run selesai. Belum ada data "
            "Firestore yang diubah."
        )

        print_status(
            "Gunakan --apply untuk menyimpan "
            "perubahan."
        )
    elif failed_documents == 0:
        print_status()
        print_status(
            "Migrasi searchKeywords berhasil."
        )
    else:
        print_status()
        print_status(
            "Migrasi selesai, tetapi masih ada "
            "dokumen yang gagal diproses."
        )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Menambahkan atau memperbarui "
            "searchKeywords pada collection batches."
        )
    )

    parser.add_argument(
        "--apply",
        action="store_true",
        help=(
            "Menyimpan perubahan ke Firestore. "
            "Tanpa opsi ini hanya dry run."
        ),
    )

    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help=(
            "Membatasi dokumen langsung pada "
            "query Firestore. Contoh: --limit 10"
        ),
    )

    arguments = parser.parse_args()

    if (
        arguments.limit is not None
        and arguments.limit <= 0
    ):
        parser.error(
            "--limit harus lebih dari 0."
        )

    return arguments


def main() -> None:
    arguments = parse_arguments()

    try:
        migrate_search_keywords(
            apply_changes=arguments.apply,
            maximum_documents=arguments.limit,
        )
    except KeyboardInterrupt:
        print_status()
        print_status(
            "Proses dihentikan oleh pengguna."
        )

        raise SystemExit(130)
    except FileNotFoundError as error:
        print_status()
        print_status(
            f"ERROR: {error}"
        )

        raise SystemExit(1) from error
    except Exception as error:
        print_status()
        print_status(
            f"ERROR: {error}"
        )

        raise SystemExit(1) from error


if __name__ == "__main__":
    main()