-- Preferencias do usuario que acompanham a conta entre dispositivos.
-- O tema da colecao (identificador do front, validado no backend) e a primeira;
-- a tabela e o lugar de preferencias futuras, uma linha por usuario.
--
-- Renumerada de V53: a versao anterior criava FK para `users`, que falha no MariaDB
-- de producao por divergencia de collation (errno 150) e derruba o boot inteiro.
-- Integridade fica na aplicacao (a exclusao de conta anonimiza, nao apaga). Collation
-- explicita porque o default do banco difere das tabelas existentes.
create table if not exists user_preferences (
  user_id varchar(255) not null,
  theme_id varchar(32) not null,
  updated_at timestamp not null,
  constraint pk_user_preferences primary key (user_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
