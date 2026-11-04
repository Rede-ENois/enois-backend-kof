-- Personalização do jogo na loja (pedido da Mel, 19/10): identidade própria do jogo, que hoje
-- era só o favicon do site de origem.
--
-- - `icon`: foto de perfil do jogo, alternativa ao favicon (vence os dois na loja).
-- - `banner` + `banner_html`: faixa do topo da página do jogo, por FOTO ou por HTML editável —
--   as duas opções, a mesma ideia do banner do perfil. A foto vence quando as duas existem.
alter table games add column if not exists icon varchar(500);
alter table games add column if not exists banner varchar(500);
alter table games add column if not exists banner_html longtext;