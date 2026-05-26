-- Migration 04 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "notification_preferences" }};
DROP TABLE IF EXISTS {{ .Schema }}.{{ T "password_reset_tokens" }};
DROP TABLE IF EXISTS {{ .Schema }}.{{ T "user_sessions" }};
DROP TABLE IF EXISTS {{ .Schema }}.{{ T "users" }};
DROP TYPE  IF EXISTS {{ .Schema }}.{{ E "user_role" }};
