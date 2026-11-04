-- Selos multiplos: uma pessoa pode marcar o mesmo post com mais de um selo.
--
-- A V60 criou o indice unico (post_id, user_id), que era o "um selo por pessoa por post". Agora o
-- unico par que nao pode repetir e (post_id, user_id, seal) — a mesma pessoa pode dar IMPORTANTE e
-- DICA, mas nao pode dar IMPORTANTE duas vezes.
--
-- As linhas que ja existem satisfazem o indice novo por construcao (eram unicas por pessoa), entao
-- nao ha nada a limpar antes.
alter table post_seals drop index if exists uk_post_seals_post_user;

create unique index if not exists uk_post_seals_post_user_seal on post_seals (post_id, user_id, seal);
