-- Lembrete de descanso entre 00:00 e 04:59 (horário local do dispositivo).
-- Default true para contas novas E existentes; quem já desligou outras preferências mantém o resto.
alter table user_preferences
  add column if not exists night_rest_reminder boolean not null default true;
