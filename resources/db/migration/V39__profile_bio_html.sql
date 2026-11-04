-- Bio do perfil tambem aceita HTML/CSS (uma "mini pagina" no perfil), com o mesmo tratamento do
-- post de pagina: sanitizado no servidor com allowlist de tags/atributos e CSS, e renderizado num
-- iframe isolado no front. longtext porque a coluna guarda markup, nao uma linha de texto.
alter table users add column bio_html longtext;
