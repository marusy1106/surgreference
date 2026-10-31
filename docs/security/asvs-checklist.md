# Чек-лист OWASP ASVS (backend и админка)

Цель — ASVS Level 2 для API и админки (docs/04, 4.13). Статусы: ✅ сделано (в скобках — чем проверено), 🟡 частично, ⏳ этап, на котором появится, — не применимо.
Обновляется в конце каждого этапа. Последнее обновление — этап 5 (API контента).

## V2. Аутентификация

| Требование | Статус | Где / чем проверено |
|---|---|---|
| Пароль ≥ 10 символов, без требований к составу, проверка по списку распространённых и похожести на email/никнейм | ✅ | `AUTH_PASSWORD_VALIDATORS`; `test_register_validation`, `test_register_password_similar_to_nickname_rejected` |
| Хеширование Argon2id с подобранными параметрами, пересчёт устаревших хешей при входе | ✅ | `TunedArgon2PasswordHasher`; `test_production_hasher_is_argon2id`, `test_login_upgrades_outdated_password_hash` |
| Ограничение перебора паролей: 5/мин на IP+email, 20/час на email, блокировка на 15 мин после 10 неудач + письмо | ✅ | `services.login`; `test_login_rate_limited_per_ip_and_email`, `test_login_locked_after_ten_failures_and_owner_notified` |
| Одинаковый ответ для существующих и несуществующих аккаунтов (вход, регистрация, сброс, повторная отправка кода) | ✅ | `test_login_wrong_password_and_unknown_email_look_the_same`, `test_register_existing_email_same_response_and_owner_notified`, `test_*_unknown_email_same_response` |
| Выравнивание времени ответа при входе с несуществующим email | ✅ | `services.login` (хеширование пароля вхолостую) |
| Одноразовые коды: CSPRNG, хранится HMAC, TTL 15 мин, ≤ 5 попыток, одноразовые, новый код гасит старый | ✅ | `codes.py`; `test_code_brute_force_blocked_after_five_attempts`, `test_expired_code_rejected`, `test_resend_respects_cooldown_and_replaces_code` |
| Уведомление о смене/сбросе пароля и о блокировке входа | ✅ | `emails.py`; тесты сброса и блокировки |
| MFA для администраторов (TOTP + резервные коды) | ✅ | `OTPAdminSite`; `test_admin_closed_without_second_factor`, `test_admin_open_with_totp`, `test_admin_backup_code_is_single_use` |
| Смена email с подтверждением нового адреса | ⏳ | после этапа 3; до этого — через поддержку |
| Капча при аномальном росте регистраций | ⏳ 7 | флаг `registration_captcha` есть, интеграция Yandex SmartCaptcha — к бете |

## V3. Управление сессиями

| Требование | Статус | Где / чем проверено |
|---|---|---|
| Access-токен короткоживущий (15 мин), подпись HS256 с `kid`, проверка `iss`, `exp`, `scope` | ✅ | `tokens.py`; `test_expired_or_forged_access_rejected` |
| Refresh — случайные 256 бит, в БД только SHA-256, ротация при каждом обновлении | ✅ | `test_refresh_rotates_tokens` |
| Обнаружение повторного использования refresh → отзыв сессии + событие + письмо | ✅ | `test_refresh_reuse_revokes_session` |
| Скользящий (30 дн) и абсолютный (90 дн) срок сессии | ✅ | `test_refresh_respects_absolute_lifetime` |
| Мгновенный отзыв: denylist `sid` в Redis на время жизни access | ✅ | `test_logout_revokes_immediately`, `test_sessions_list_and_revoke` |
| Список устройств, завершение одной/всех кроме текущей; чужую сессию завершить нельзя | ✅ | `test_cannot_revoke_foreign_session`, `test_revoke_all_other_sessions` |
| Не более 10 активных сессий | ✅ | `test_oldest_session_evicted_over_limit` |
| Сброс/смена пароля завершают другие сессии | ✅ | `test_password_reset_flow`, `test_password_change_keeps_current_session_only` |
| Админка: cookie `Secure`, `HttpOnly`, `SameSite=Strict`, таймаут 30 мин бездействия | ✅ | `settings/base.py`, `settings/prod.py`; `check --deploy` |

## V4. Контроль доступа

| Требование | Статус | Где / чем проверено |
|---|---|---|
| Закрыто по умолчанию: `IsAuthenticated` глобально, публичные эндпоинты — явный список | ✅ | `REST_FRAMEWORK`; `test_requests_without_token_rejected` |
| Объектный доступ (IDOR): выборки фильтруются по `request.user` | ✅ | сессии (`test_cannot_revoke_foreign_session`), попытки тестов и кейсов — чужие отдают 404 (`test_foreign_attempt_is_not_found` в assessment и cases) |
| Роли сотрудников с наименьшими привилегиями, аналитик без доступа к email | ✅ | `roles.py`; `test_roles_synced_with_least_privilege` |
| Роли выдаёт только superadmin, изменение — в журнал и письмо остальным superadmin | ✅ | `UserAdmin`; `test_only_superadmin_changes_roles` |
| Пользователей нельзя удалить из админки — только обезличить | ✅ | `test_users_cannot_be_deleted_only_anonymized` |
| Правила редакционного процесса (рецензент ≠ автор, публикует chief_editor) | 🟡 | ограничения БД — ✅ (этап 2); проверка роли при публикации — ⏳ 5 |
| Админка только из allowlist IP / VPN | ⏳ 8 | reverse proxy |

## V5. Валидация входных данных

| Требование | Статус | Где / чем проверено |
|---|---|---|
| Все входные данные через сериализаторы, ORM без сырого SQL | ✅ | `serializers.py`; ruff `S608` |
| Ограничение размера тела запроса (1 МБ) | ✅ | `DATA_UPLOAD_MAX_MEMORY_SIZE` |
| Только JSON на входе и выходе | ✅ | `DEFAULT_PARSER_CLASSES`, `DEFAULT_RENDERER_CLASSES` |
| Блок-лист одноразовых почтовых доменов | ✅ | `disposable.py`; `test_register_validation` |
| Правильные ответы и качество выборов в кейсе не уходят клиенту до ответа | ✅ | `test_start_hides_correct_answers`, `test_list_and_start_hide_choice_quality` |
| Ответ принимается только для вопроса и вариантов своей попытки, выбор в кейсе — только на текущем шаге | ✅ | `test_answer_validation`, `test_choice_from_another_step_is_rejected` |
| Антифрод XP: идемпотентные начисления, лимит 500 XP в сутки, повтор теста/кейса — только прирост, слишком быстрые ответы без XP, лимит стартов попыток | ✅ | `apps/gamification/tests`, `test_too_fast_answers_are_flagged_and_earn_no_xp` |

## V7. Журналирование

| Требование | Статус | Где / чем проверено |
|---|---|---|
| События безопасности 4.10 пишутся в append-only журнал | 🟡 | регистрация, подтверждение, вход/неудача/блокировка, выход, refresh reuse, сброс и смена пароля, отзыв сессий, удаление, экспорт, вход в админку, неверный TOTP, подключение MFA, смена ролей — ✅; изменение флагов и тарифов, массовые выгрузки, антифрод — ⏳ 5–6 |
| В журнале нет паролей, кодов, токенов | ✅ | `test_security_log_has_no_secrets` |
| Журналы нельзя изменить или удалить (приложение + права БД) | ✅ | `AppendOnlyModel`, `infra/postgres/roles.sql`; `apps/audit/tests` |
| Действия в админке дублируются в append-only журнал | ✅ | `audit/receivers.py`; `test_admin_log_entry_copied_to_append_only_journal` |
| Журналы видит только superadmin | ✅ | `test_audit_logs_visible_only_to_superadmin` |
| Алерты в Telegram (всплеск неудачных входов, reuse, вход в админку с нового IP) | ⏳ 7 | |
| Хранение журнала 1 год, затем удаление | ⏳ 7 | задача очистки под ролью владельца схемы |

## V8. Защита данных (152-ФЗ)

| Требование | Статус | Где / чем проверено |
|---|---|---|
| Отдельное согласие на обработку ПД с версией документа | ✅ | `services.register`; `test_register_validation` (без согласия — 400), `test_consents_listed` |
| Удаление аккаунта внутри приложения: обезличивание, отзыв сессий и согласий, запись в `pd_requests` | ✅ | `test_account_deletion_anonymizes`, `apps/universities/tests/test_account_signals.py` |
| Выгрузка данных субъекта | ✅ | `test_data_export_sent_once_a_day` |
| Неподтверждённые аккаунты обезличиваются через 7 дней | ✅ | Celery beat `accounts.cleanup`; `test_cleanup_anonymizes_stale_unverified` |
| Email и другие ПД не попадают в ключи Redis в открытом виде | ✅ | `ratelimit.digest` |
| Очистка `analytics_events.user_id` при удалении | ⏳ 6 | через сигнал `account_deleted` |

## V9, V14. Транспорт и конфигурация

| Требование | Статус | Где / чем проверено |
|---|---|---|
| HTTPS, HSTS, редирект с HTTP | ✅ | `settings/prod.py`; `check --deploy` |
| Секреты только из окружения, prod не стартует с dev-ключами JWT или короткими ключами | ✅ | `settings/prod.py`; gitleaks в CI и pre-commit |
| Зависимости без известных уязвимостей | ✅ | `pip-audit` в CI |
| Заголовки безопасности админки: `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy` | ✅ | `settings/base.py` |
| CSP для админки | ⏳ 7 | |
| SAST (bandit через ruff `S`, semgrep), DAST (ZAP), пентест | 🟡 | ruff `S` — ✅ в CI; semgrep, ZAP, пентест — ⏳ 7 |
