-- Marketplace de QUALQUER coisa, não só tema de galeria: template, banner, página,
-- post, blog e serviço. O conteúdo vendido fica aqui (HTML/texto) e é entregue ao
-- comprador pela tela "Minhas compras", com editor de texto e cópia do HTML.
--
-- Tema continua apontando para theme_gallery (item_kind=THEME); os demais tipos
-- apontam para marketplace_items. Nada de FK entre as tabelas (mesma armadilha de
-- collation que o resto do schema evita).
create table if not exists marketplace_items (
  id varchar(64) not null,
  seller_id varchar(64) not null,
  kind varchar(20) not null,
  title varchar(160) not null,
  description varchar(500),
  content longtext,
  created_at timestamp not null,
  primary key (id),
  key idx_marketplace_items_seller (seller_id, created_at),
  key idx_marketplace_items_kind (kind, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
