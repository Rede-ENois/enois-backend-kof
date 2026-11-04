-- Cada pedido de suporte vira uma issue num repositorio PRIVADO do GitHub. O numero e a URL
-- ficam aqui para fechar/reabrir dos dois lados (painel <-> GitHub).
--
-- Repositorio privado de proposito: o ticket tem texto livre e e-mail de contato; os repos
-- publicos do projeto nao podem receber esse conteudo.
alter table support_requests add column if not exists github_issue_number int null;
alter table support_requests add column if not exists github_issue_url varchar(255) null;

-- O webhook do GitHub chega so com o numero da issue: este indice e o caminho de volta.
create index if not exists idx_support_requests_github_issue
  on support_requests (github_issue_number);

-- Configuracao do espelho (token, repo e segredo do webhook), CIFRADA com a chave do app.
-- Fica no banco para o token nao precisar ir para o manifesto do GitOps; o painel troca sem
-- reiniciar o pod. Nome logico -> ciphertext.
create table if not exists support_settings (
  name varchar(64) not null,
  value_cipher varchar(4096) not null,
  updated_at timestamp not null,
  primary key (name)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
