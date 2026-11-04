-- Cadastro de quem quer contribuir com o projeto open source.
-- A landing é pública, então a linha guarda o aceite dos termos e a data para documentação.
create table if not exists contributor_applications (
  id varchar(64) not null,
  name varchar(120) not null,
  github varchar(120) not null,
  email varchar(180) not null,
  area varchar(80) null,
  experience varchar(40) null,
  message varchar(2000) null,
  accepted_terms_at timestamp not null,
  status varchar(24) not null,
  created_at timestamp not null,
  primary key (id),
  key idx_contributor_applications_created (created_at),
  key idx_contributor_applications_status (status)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
