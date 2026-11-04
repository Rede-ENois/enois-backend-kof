-- "Apagar para mim" por MENSAGEM (o da conversa inteira ja existia). Marca por usuario: a mensagem
-- continua na conversa para o outro participante, some so de quem apagou. Sem FK de proposito
-- (mesma licao de collation das outras tabelas).
create table if not exists message_hidden (
  id varchar(255) not null,
  user_id varchar(255) not null,
  message_id varchar(255) not null,
  created_at timestamp not null,
  constraint pk_message_hidden primary key (id),
  constraint uk_message_hidden unique (user_id, message_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
