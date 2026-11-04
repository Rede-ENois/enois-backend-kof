-- Ranking OPCIONAL (pedido via suporte, 19/10): quem nao curte competicao desliga a secao de
-- ranking no proprio perfil. Preferencia da CONTA (nao do perfil visitado) — vale para quem le.
alter table users add column if not exists show_ranking boolean not null default true;
