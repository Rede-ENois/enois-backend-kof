-- Autorização administrativa por FLAG imutável, não por username/e-mail mutáveis (EN-01/E-01).
-- A semeadura é única: a partir daqui o papel só muda por operação de banco/admin.
alter table users add column is_admin boolean not null default false;
update users set is_admin = true where lower(username) in ('aminadojava', 'mrfoxxo');

-- Purga hashes de senha e respostas com tokens gravados pela idempotência de autenticação
-- (E-03/E-19). O código novo não persiste mais esses corpos.
delete from idempotency_keys where route like '/api/auth/%';

-- Troca de e-mail em duas etapas (E-02/E-11): o endereço novo só vale depois do clique no link
-- enviado para ele. Uma linha por usuário; o token é guardado como hash.
create table if not exists pending_email_changes (
  id varchar(64) not null,
  user_id varchar(64) not null,
  new_email varchar(160) not null,
  token_hash char(64) not null,
  expires_at timestamp not null,
  created_at timestamp not null,
  primary key (id),
  unique key uk_pending_email_user (user_id),
  unique key uk_pending_email_token (token_hash)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
