-- Segundo fator (authenticator TOTP ou codigo por e-mail) e o estado de "conta verificada".
--
-- Decisao de desenho: os SEGREDOS ficam numa tabela propria (user_two_factor_secrets), nunca no
-- dominio de perfil, e o TOTP e guardado cifrado (AES-GCM com chave da aplicacao). Em `users` ficam
-- apenas os instantes de ativacao, que nao sao segredo e servem para o calculo de credibilidade.
--
-- Mesmos cuidados das V18 a V22: `if not exists`, sem FK entre tabelas com collation diferente e
-- backfill que nao invalida o que ja existe.

alter table users add column if not exists totp_enabled_at timestamp null;
alter table users add column if not exists email_otp_enabled_at timestamp null;

create table if not exists user_two_factor_secrets (
  user_id varchar(255) not null,
  totp_secret_encrypted varchar(512) null,
  pending_secret_encrypted varchar(512) null,
  pending_created_at timestamp null,
  updated_at timestamp not null,
  primary key (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- Desafio do segundo fator no login: id opaco, sem token de sessao. O codigo por e-mail e guardado
-- como hash (o valor em claro so existe no e-mail). `attempts` limita tentativa e erro.
create table if not exists two_factor_challenges (
  id varchar(255) not null,
  user_id varchar(255) not null,
  method varchar(16) not null,
  code_hash varchar(255) null,
  attempts int not null default 0,
  expires_at timestamp not null,
  consumed_at timestamp null,
  created_at timestamp not null,
  primary key (id),
  key idx_two_factor_challenges_user (user_id),
  key idx_two_factor_challenges_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- Codigos de recuperacao: uso unico, guardados como hash, mostrados uma unica vez na ativacao.
create table if not exists two_factor_backup_codes (
  code_hash varchar(255) not null,
  user_id varchar(255) not null,
  used_at timestamp null,
  created_at timestamp not null,
  primary key (code_hash),
  key idx_two_factor_backup_codes_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;