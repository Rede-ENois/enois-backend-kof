-- Conversa do ticket de suporte espelhada no GitHub: cada resposta do painel vira comentário na
-- issue e cada comentário novo na issue aparece no painel. `github_comment_id` evita duplicar o
-- comentário que o próprio Énóis publicou quando o webhook devolve o evento.
create table if not exists support_messages (
  id varchar(64) not null,
  request_id varchar(64) not null,
  direction varchar(20) not null,
  author_name varchar(200) null,
  author_github_login varchar(100) null,
  body varchar(4000) not null,
  github_comment_id bigint null,
  created_at timestamp not null,
  primary key (id),
  unique key uk_support_messages_comment (github_comment_id),
  key idx_support_messages_request (request_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;