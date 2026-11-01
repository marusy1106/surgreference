# SurgReference — backend

Django 5.2 + DRF, PostgreSQL 16, Redis, Celery. Модульный монолит: `apps/*` (см. [docs/02-architecture.md](../docs/02-architecture.md)).

## Запуск через Docker (рекомендуется)

```bash
cp .env.example .env            # из корня surgreference/, заполнить DJANGO_SECRET_KEY
docker compose -f infra/docker-compose.yml up --build
```

- API: http://localhost:8000/api/v1/health, Swagger: http://localhost:8000/api/v1/docs/
- Админка: http://localhost:8000/admin/ — вход только со вторым фактором, см. «Доступ в админку»
- Письма: http://localhost:8025 (Mailpit), файлы: http://localhost:9001 (MinIO)

## Запуск без Docker (macOS, Homebrew)

```bash
brew services start postgresql@18 && createdb surgreference
brew install redis && brew services start redis
cd backend && python3.13 -m venv .venv && .venv/bin/pip install -r requirements/dev.txt
# в ../.env: DATABASE_URL=postgres://localhost:5432/surgreference,
#            EMAIL_URL=consolemail:// и CELERY_TASK_ALWAYS_EAGER=true — письма с кодами печатаются в консоль сервера
.venv/bin/python manage.py migrate
.venv/bin/python manage.py runserver
```

## Демо-контент

```bash
.venv/bin/python manage.py seed_demo_content   # дисциплины, тема «Острый аппендицит» (урок, тест), кейс
.venv/bin/python manage.py seed_demo_editorial # автор, рецензент хирургии, главный редактор и черновик урока
.venv/bin/python manage.py seed_demo_references # фрагмент МКБ-10, три КР; ссылки на них в демо-уроке (seed_demo_content делает это сам)
```

Только при `DEBUG=True` (для стенда беты — `--force`). Авторы контента — неактивные служебные пользователи.

`seed_demo_editorial` (только `DEBUG=True`) создаёт трёх демо-сотрудников `demo-author@`, `demo-reviewer@`, `demo-editor@example.org` с новым общим паролем — он печатается один раз при каждом запуске. В dev админка пускает по паролю, без второго фактора (`ADMIN_REQUIRE_OTP=False`); чтобы проверить вход с кодом, запустите с `ADMIN_REQUIRE_OTP=true` и подключите его: `manage.py enroll_totp --reset demo-author@example.org`.

## Доступ в админку

В prod админка открывается только после второго фактора (TOTP), без него вход не пускает дальше формы; prod-настройки не запускаются с `ADMIN_REQUIRE_OTP=False`.

```bash
.venv/bin/python manage.py createsuperuser
.venv/bin/python manage.py enroll_totp you@example.org        # QR-код + 10 резервных кодов, показываются один раз
.venv/bin/python manage.py enroll_totp you@example.org --reset  # если телефон утерян
```

Роли сотрудников (`content_author`, `medical_reviewer`, `chief_editor`, `support`, `analyst`) создаются при `migrate`
из `apps/accounts/roles.py`; выдаёт их только суперпользователь, каждое изменение — в журнале безопасности.

## Проверки (то же, что в CI)

```bash
.venv/bin/ruff check . && .venv/bin/ruff format --check .
.venv/bin/lint-imports                                   # границы модулей
.venv/bin/python manage.py makemigrations --check --dry-run
.venv/bin/pytest --cov
.venv/bin/pip-audit -r requirements/base.txt
```

## Ручная проверка авторизации

Swagger (http://localhost:8000/api/v1/docs/) → `POST /auth/register` → код из письма → `POST /auth/verify-email` →
кнопка Authorize с `access`. Что должно получиться:

- 5 неверных кодов подряд — и даже верный код больше не принимается;
- повторный `POST /auth/refresh` со старым refresh → 401, а новый access этой сессии → `session_revoked`;
- 6-я попытка входа за минуту с одного IP на один email → 429; 10 неудачных входов в течение часа →
  вход заблокирован на 15 минут, владельцу уходит письмо;
- в админке «Журнал безопасности» видны все эти события, без паролей, кодов и токенов.

## Правила

- Бизнес-логика — в `services.py` (команды) и `selectors.py` (запросы); `api/` — тонкий слой.
- Нижние модули не импортируют верхние (`lint-imports` валит сборку).
- Перечисления — `TextChoices` на уровне модуля + `choices_check()` (CHECK в БД).
- Опубликованный контент не меняется: правка = новая версия.
- Секреты — только через переменные окружения; `.env` не коммитится.
