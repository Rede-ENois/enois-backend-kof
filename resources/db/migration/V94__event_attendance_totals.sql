-- Presença em eventos como CONTRIBUIÇÃO PERMANENTE: o sanitizador apaga as linhas de
-- `event_attendees` (retenção de PII), e sem este agregado a credibilidade de quem participou
-- caía sozinha com o tempo. O total por usuário não é PII (só a contagem) e é somado ao vivo
-- com as presenças ainda existentes.
create table if not exists user_event_attendance_totals (
  user_id varchar(255) not null,
  total int not null default 0,
  primary key (user_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
