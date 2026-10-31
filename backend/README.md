# SurgReference — backend

Django 5.2 + DRF, PostgreSQL 16, Redis, Celery. Модульный монолит: `apps/*` (см. [docs/02-architecture.md](../docs/02-architecture.md)).

## Запуск через Docker (рекомендуется)

```bash
cp .env.example .env            # из корня surgreference/, заполнить DJANGO_SECRET_KEY
docker compose -f infra/docker-compose.yml up --build
```

- API: http://localhost:8000/api/v1/health, Swagger: http://localhost:8000/api/v1/docs/
- Админка: http://localhost:8000/admin/ (создать пользователя: `docker compose -f infra/docker-compose.yml exec api python manage.py createsuperuser`)
- Письма: http://localhost:8025 (Mailpit), файлы: http://localhost:9001 (MinIO)

## Запуск без Docker (macOS, Homebrew)

```bash
brew services start postgresql@18 && createdb surgreference
brew install redis && brew services start redis
cd backend && python3.13 -m venv .venv && .venv/bin/pip install -r requirements/dev.txt
# в ../.env: DATABASE_URL=postgres://localhost:5432/surgreference
.venv/bin/python manage.py migrate
.venv/bin/python manage.py runserver
```

## Проверки (то же, что в CI)

```bash
.venv/bin/ruff check . && .venv/bin/ruff format --check .
.venv/bin/lint-imports                                   # границы модулей
.venv/bin/python manage.py makemigrations --check --dry-run
.venv/bin/pytest --cov
.venv/bin/pip-audit -r requirements/base.txt
```

## Правила

- Бизнес-логика — в `services.py` (команды) и `selectors.py` (запросы); `api/` — тонкий слой.
- Нижние модули не импортируют верхние (`lint-imports` валит сборку).
- Перечисления — `TextChoices` на уровне модуля + `choices_check()` (CHECK в БД).
- Опубликованный контент не меняется: правка = новая версия.
- Секреты — только через переменные окружения; `.env` не коммитится.
