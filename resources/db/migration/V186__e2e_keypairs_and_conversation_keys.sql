-- E2E messaging: chaves de cada usuario e chave simetrica por conversa.
--
-- user_e2e_keypairs: a chave publica em claro (pra quem quer mandar msg) e a privada
-- cifrada com derivacao da senha do usuario (backup recuperavel em outro device).
-- Uma conta pode ter mais de um keypair (rotacao), mas so um ativo.
create table if not exists user_e2e_keypairs (
  id varchar(255) not null,
  user_id varchar(255) not null,
  public_key text not null,
  encrypted_private_key text not null,
  algorithm varchar(32) not null,
  active boolean not null default true,
  created_at timestamp not null,
  primary key (id),
  key idx_e2e_keypairs_user (user_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

-- conversation_e2e_keys: chave simetrica da conversa, cifrada com a publica de cada participante.
-- Cada participante tem sua copia (cifrada com SUA chave publica).
create table if not exists conversation_e2e_keys (
  conversation_id varchar(255) not null,
  user_id varchar(255) not null,
  encrypted_key text not null,
  key_version int not null default 1,
  created_at timestamp not null,
  primary key (conversation_id, user_id),
  constraint fk_conv_e2e_conv foreign key (conversation_id) references conversations (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

-- Flag na mensagem: se e2e = true, o campo text contem ciphertext (base64).
-- Mensagens antigas ficam com e2e = false (texto em claro, como sempre foram).
alter table messages add column if not exists e2e boolean not null default false;
alter table messages add column if not exists iv varchar(44) null;

-- Ciphertext base64 e ~33% maior que plaintext. 5000 chars viram ~6700. Sobe pra 8000.
alter table messages modify text varchar(8000) not null;
