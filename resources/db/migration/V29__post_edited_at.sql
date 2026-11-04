-- Marca quando o post foi editado pelo autor (nulo enquanto nunca editado).
alter table posts add column edited_at timestamp;
