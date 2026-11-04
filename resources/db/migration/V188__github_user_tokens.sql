-- Token OAuth de escrita do GitHub por pessoa, para responder issues e revisar PRs em nome dela.
-- Fica CIFRADO (REDE_SECURITY_ENCRYPTION_KEY); sem a chave, nada é gravado. Escopo `repo` é o
-- necessário para o repositório privado de suporte; sem ele a linha não existe e o painel usa o
-- token de serviço com atribuição.
create table if not exists github_user_tokens (
  user_id varchar(64) not null,
  token_cipher text not null,
  scopes varchar(255) null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (user_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;