-- Modo lite: menos animações e menos requisições para aparelhos fracos / internet ruim.
-- Default false: quem já usa a conta mantém a experiência completa.
alter table user_preferences
  add column if not exists lite_mode boolean not null default false;
