"""Импорт МКБ-10 из выгрузки НСИ Минздрава (справочник 1.2.643.5.1.13.13.11.1005, nsi.rosminzdrav.ru).

Файл — CSV или JSON с полями ID, ID_PARENT, MKB_CODE, MKB_NAME и ACTUAL. Повторный импорт обновляет
названия и иерархию; коды, которых нет в новой выгрузке, не удаляются (на них могут ссылаться уроки),
версия импорта видна в nsi_version.
"""

import csv
import json
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.content.models import ICD10Code

CODE_LENGTH = ICD10Code._meta.get_field("code").max_length


def read_rows(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8-sig")
    if path.suffix.lower() == ".json":
        data = json.loads(text)
        return data if isinstance(data, list) else data.get("list") or data.get("rows") or []
    dialect = csv.Sniffer().sniff(text[:4096], delimiters=";,\t")
    return list(csv.DictReader(text.splitlines(), dialect=dialect))


def is_actual(row) -> bool:
    return str(row.get("ACTUAL", "1")).strip().lower() in ("1", "true", "да", "")


class Command(BaseCommand):
    help = "Импорт МКБ-10 из выгрузки НСИ Минздрава (CSV или JSON)"

    def add_arguments(self, parser):
        parser.add_argument("path", type=Path)
        parser.add_argument("--nsi-version", required=True, help="версия справочника в НСИ, например 5.12")

    def handle(self, path, nsi_version, **options):
        if not path.exists():
            raise CommandError(f"Файл не найден: {path}")
        rows = [r for r in read_rows(path) if is_actual(r) and str(r.get("MKB_CODE", "")).strip()]
        if not rows:
            raise CommandError("В файле нет актуальных записей с полями MKB_CODE и MKB_NAME")

        by_id = {str(r["ID"]).strip(): r for r in rows}
        code_of = {key: str(r["MKB_CODE"]).strip() for key, r in by_id.items()}
        parent_of = {code_of[key]: code_of.get(str(r.get("ID_PARENT") or "").strip()) for key, r in by_id.items()}
        too_long = [c for c in parent_of if len(c) > CODE_LENGTH]
        if too_long:
            raise CommandError(f"Коды длиннее {CODE_LENGTH} символов: {', '.join(too_long[:5])}")
        has_children = {p for p in parent_of.values() if p}

        def chain(code):
            path, node = [], code
            while node and len(path) < 10:
                path.append(node)
                node = parent_of.get(node)
            return path[::-1]

        codes = []
        for key, row in by_id.items():
            code = code_of[key]
            lineage = chain(code)
            codes.append(
                ICD10Code(
                    code=code,
                    parent_id=parent_of[code],
                    title=str(row["MKB_NAME"]).strip()[:500],
                    chapter=lineage[0] if len(lineage) > 1 else "",
                    block=lineage[1] if len(lineage) > 2 else "",
                    is_leaf=code not in has_children,
                    nsi_version=nsi_version,
                )
            )
        with transaction.atomic():
            ICD10Code.objects.bulk_create(
                codes,
                update_conflicts=True,
                unique_fields=["code"],
                update_fields=["parent", "title", "chapter", "block", "is_leaf", "nsi_version"],
                batch_size=1000,
            )
        self.stdout.write(self.style.SUCCESS(f"МКБ-10: импортировано {len(codes)} записей, версия НСИ {nsi_version}"))
