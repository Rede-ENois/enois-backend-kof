-- Inscricoes de Web Push (notificacoes no celular/navegador).
--
-- Sem FK para users e com charset explicito, igual a V18: o banco de producao usa
-- utf8mb4_unicode_ci como default e a tabela users esta em utf8mb4_uca1400_ai_ci, e FK entre
-- collations diferentes falha no boot (ja aconteceu). IF NOT EXISTS pelo mesmo motivo da V18:
-- a migracao precisa ser segura para reaplicar.
--
-- endpoint e uma URL longa. 700 caracteres cabem no limite de chave do InnoDB (3072 bytes em
-- utf8mb4) sem precisar de indice com prefixo -- e esse prefixo o H2 (usado nos testes) nao
-- aceita, o que derrubava o boot dos testes.
create table if not exists push_subscriptions (
  id varchar(255) not null,
  user_id varchar(255) not null,
  endpoint varchar(700) not null,
  p256dh varchar(255) not null,
  auth varchar(255) not null,
  created_at timestamp not null,
  last_seen_at timestamp null,
  primary key (id),
  constraint uk_push_subscriptions_endpoint unique (endpoint),
  key idx_push_subscriptions_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;