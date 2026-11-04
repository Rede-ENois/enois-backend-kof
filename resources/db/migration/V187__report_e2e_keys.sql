-- Chave E2E anexada a denuncia de mensagem: o denunciante entrega a chave da conversa
-- pra que o moderador possa decifrar o conteudo denunciado. Sem a chave, o moderador ve ciphertext.
create table if not exists report_e2e_keys (
  report_id varchar(255) not null,
  conversation_key text not null,
  created_at timestamp not null,
  primary key (report_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
