-- Posts do tipo PAGE: o autor cola um HTML e ele vira uma mini pagina renderizada dentro do post.
-- O backend sanitiza antes de gravar (allowlist de tags/atributos + CSS), mas a coluna guarda
-- exatamente o que foi sanitizado, para que o render (iframe sandboxed) nao precise reprocessar.
--
-- LONGTEXT (e nao varchar) porque HTML ocupa espaco de verdade: uma pagina colada passa facil dos
-- limites de varchar, que ainda esbarram no tamanho maximo da linha InnoDB. Guardado fora da
-- linha, o tamanho da pagina deixa de disputar espaco com as outras colunas de posts.
alter table posts add column page_html longtext;
