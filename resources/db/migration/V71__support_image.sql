-- Anexo de imagem nos pedidos de suporte: a URL do CDN (upload pela media do app)
-- vai para o e-mail do time como anexo e aparece no painel /admin/support.
alter table support_requests add column if not exists image_url varchar(500) null;
