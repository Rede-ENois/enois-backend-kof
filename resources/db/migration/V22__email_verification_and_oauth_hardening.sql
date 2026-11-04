-- Verificacao de e-mail no cadastro + endurecimento do login social.
--
-- Mesmos cuidados das V18 a V21: `if not exists` (o DDL do MariaDB nao e transacional e uma falha
-- no meio deixa a versao marcada como FAILED, o que trava o rollout) e nenhuma FK entre tabelas com
-- collation diferente.

-- 1) Estado de verificacao da conta.
alter table users add column if not exists email_verified_at timestamp null;

-- Contas criadas antes desta migracao continuam valendo: elas nasceram quando a verificacao nao
-- existia. Trancar todo mundo de uma vez seria transformar uma melhoria em indisponibilidade.
update users set email_verified_at = created_at where email_verified_at is null;

-- Mesmo desenho do reset de senha (V9): guardamos apenas o hash do token, com validade e uso unico.
create table if not exists email_verification_tokens (
  token varchar(255) not null,
  user_id varchar(255) not null,
  expires_at timestamp not null,
  used_at timestamp null,
  created_at timestamp not null,
  primary key (token),
  key idx_email_verification_tokens_user (user_id),
  key idx_email_verification_tokens_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- 2) Quem entrou por login social tem uma credencial com senha aleatoria que nao conhece. Sem esta
-- marca nao da para saber se desvincular o provedor tiraria o acesso da pessoa para sempre.
alter table user_credentials add column if not exists password_usable boolean not null default true;

-- 3) O `state` do OAuth deixa de viver so em cookie: passa a ser registrado no servidor, com o
-- `nonce` e a validade, para ser conferido e consumido uma unica vez no callback.
create table if not exists oauth_authorization_requests (
  state varchar(255) not null,
  provider varchar(32) not null,
  nonce varchar(255) not null,
  user_id varchar(255) null,
  expires_at timestamp not null,
  created_at timestamp not null,
  primary key (state),
  key idx_oauth_authorization_requests_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;