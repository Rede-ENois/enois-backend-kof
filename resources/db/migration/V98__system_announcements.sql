-- Comunicados de SISTEMA com garantia de envio único (a chave é a idempotência do comunicado).
-- O primeiro uso é o pedido de desculpas pelo incidente de armazenamento de mídia (ImageKit),
-- com 100 faíscas para cada usuário — disparado quando o S3 volta a aceitar uploads.
create table if not exists system_announcements (
  announcement_key varchar(64) not null,
  sent_at timestamp not null,
  primary key (announcement_key)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
