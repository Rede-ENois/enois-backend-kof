-- Edicao de comentario proprio: guarda quando o texto foi alterado para a interface
-- poder marcar "editado" (mesmo padrao de posts.edited_at, na V29).
alter table comments add column edited_at timestamp;
