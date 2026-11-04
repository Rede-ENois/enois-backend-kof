-- A coluna `user_projects.html` de producao veio de um schema legado. Um payload com a seta
-- Unicode U+2192 falha, enquanto o mesmo HTML trocando apenas a seta por ASCII persiste. Localmente
-- funciona porque o banco de desenvolvimento ja usa utf8mb4. Declarar o charset na coluna evita
-- depender do default que existia quando a tabela foi criada.
--
-- O LONGTEXT tambem alinha o armazenamento ao teto de 20.000 caracteres do SafeHtml. A coluna nao
-- participa de indice, FK ou comparacao de negocio, entao a mudanca de collation fica isolada ao
-- conteudo HTML do card de projeto.

alter table user_projects modify column html longtext
  character set utf8mb4 collate utf8mb4_unicode_ci;
alter table user_projects modify column stack text not null;
alter table user_projects modify column diary longtext;
alter table scheduled_posts modify column page_html longtext;
