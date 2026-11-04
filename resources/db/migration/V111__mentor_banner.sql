-- Banner do perfil de mentor (imagem de capa da página/card). URL do CDN de mídia; sem FK.
alter table mentors add column if not exists banner varchar(1000) null;
