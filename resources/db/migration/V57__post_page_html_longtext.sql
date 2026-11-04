-- A coluna `page_html` nasceu `longtext` no V36, mas o banco de PRODUCAO ficou com uma coluna
-- menor: prod/hml nao validam checksum de migracao, entao uma versao anterior daquele arquivo
-- chegou a ser aplicada la. Paginas acima desse tamanho falhavam com "Data too long for column
-- 'page_html'", que o app devolve como o 409 generico "operacao conflita com o estado atual dos
-- dados" — foi o que derrubou a publicacao de uma pagina de 14 mil caracteres.
--
-- Este ALTER garante o tipo certo em qualquer banco (em banco novo e no-op, porque ja e longtext).
alter table posts modify column page_html longtext;
