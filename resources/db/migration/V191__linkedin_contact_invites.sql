-- Contatos do LinkedIn importados pelo arquivo de dados (Connections.csv) e o convite automático.
-- Guarda o MÍNIMO para convidar e não repetir: nome exibido, chave normalizada e o usuário do
-- Énóis correspondente (quando existe). Empresa/cargo/URL do contato NÃO são gravados.
create table if not exists linkedin_contact_invites (
  id varchar(64) not null,
  user_id varchar(64) not null,
  contact_name varchar(200) not null,
  name_key varchar(200) not null,
  matched_user_id varchar(64) null,
  status varchar(20) not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  unique key uk_li_contact_user_key (user_id, name_key),
  key idx_li_contact_status (status)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

-- Botão "convidar automaticamente": por pessoa, desligado por padrão.
create table if not exists linkedin_contact_preferences (
  user_id varchar(64) not null,
  auto_invite boolean not null default false,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (user_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;