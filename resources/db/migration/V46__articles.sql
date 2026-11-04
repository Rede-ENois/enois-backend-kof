-- Artigo: categoria propria, com o corpo numa tabela propria.
--
-- Por que tabela separada (e nao um campo do post): artigo tem que ser maior (4.000 caracteres) que
-- um post comum (1.200), e o corpo longo nao pertence a linha que o feed le a cada listagem. A linha
-- de `posts` continua sendo o ENVELOPE do artigo — tipo, contadores, reacoes, comentarios, salvos e
-- ordenacao do feed seguem funcionando sem uma segunda implementacao de cada um.
--
-- `posts.content` guarda o titulo/resumo; `articles.body` guarda o texto do artigo.
-- Sem FK por collation (mesma licao da V33): a tabela guarda o id e a leitura resolve.
create table articles (
  post_id varchar(255) not null,
  body varchar(4000) not null,
  created_at timestamp not null,
  edited_at timestamp,
  primary key (post_id)
);

create index idx_articles_created on articles (created_at);
