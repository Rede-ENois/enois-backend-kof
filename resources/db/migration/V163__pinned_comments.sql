-- Comentário fixado no topo da lista do post. Um por post: o serviço desfixa os demais ao
-- fixar outro. O `pinned` entra no CommentView e a listagem exclui o fixado da paginação
-- normal (ele é devolvido no topo da primeira página, sem duplicar).
alter table comments add column if not exists pinned boolean not null default false;

create index if not exists idx_comments_post_pinned on comments (post_id, pinned);
