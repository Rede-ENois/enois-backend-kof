-- Estilo seguro do nome: ids de fontes permitidas e cor hex, sem CSS livre.
alter table users add column if not exists name_font varchar(32) null;
alter table users add column if not exists name_color varchar(7) null;
