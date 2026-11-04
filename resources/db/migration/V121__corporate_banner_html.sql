-- Capa em HTML/CSS do perfil profissional, como a do perfil social. Longtext porque é markup.
alter table corporate_profiles add column if not exists banner_html longtext null;
