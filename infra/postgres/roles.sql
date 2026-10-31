-- Роли prod-БД. Выполняется администратором БД один раз после первой миграции.
-- Миграции выполняет владелец схемы (surg_owner); приложение работает под surg_app.

-- Журналы только на вставку: у приложения нет UPDATE/DELETE.
REVOKE UPDATE, DELETE, TRUNCATE ON audit_securityevent, audit_adminauditlog FROM surg_app;

-- XP-журнал: исправления только сторнирующей записью.
REVOKE UPDATE, DELETE, TRUNCATE ON gamification_xpevent FROM surg_app;
