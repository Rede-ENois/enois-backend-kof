-- Conexao de publicacao no LinkedIn (produto "Share on LinkedIn", escopo w_member_social).
-- O token de acesso fica CIFRADO pelo SecretCipher (AES-GCM). Sem REDE_SECURITY_ENCRYPTION_KEY
-- nenhuma linha e gravada e a integracao se declara indisponivel — token nunca fica em claro.
create table if not exists linkedin_connections (
  user_id varchar(64) not null,
  member_sub varchar(255) not null,
  access_token_enc text not null,
  token_expires_at timestamp not null,
  post_sync boolean not null default false,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (user_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
