-- Fundacao das paginas empresariais (COMPANY_PAGES.md Fase 1 + Fase 1.5).
-- Sem FK para users de proposito (armadilha de collation do MariaDB, errno 150);
-- integridade fica na aplicacao, como no resto do banco.

create table if not exists companies (
  id varchar(255) not null,
  slug varchar(120) not null,
  name varchar(160) not null,
  legal_name varchar(200),
  description varchar(4000),
  sector varchar(80),
  size varchar(40),
  location varchar(160),
  website varchar(300),
  logo varchar(500),
  cover varchar(500),
  owner_user_id varchar(255) not null,
  status varchar(24) not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  constraint pk_companies primary key (id),
  constraint uk_companies_slug unique (slug)
);

create index idx_companies_slug on companies (slug);

create table if not exists company_memberships (
  id varchar(255) not null,
  company_id varchar(255) not null,
  user_id varchar(255) not null,
  role varchar(20) not null,
  created_at timestamp not null,
  primary key (id)
);

create index idx_company_memberships_company on company_memberships (company_id, user_id);

create table if not exists micro_projects (
  id varchar(255) not null,
  company_id varchar(255) not null,
  created_by varchar(255) not null,
  title varchar(200) not null,
  problem text not null,
  scope text,
  deliverables text,
  acceptance_criteria text,
  budget varchar(160),
  deadline date,
  status varchar(20) not null,
  selected_proposal_id varchar(255),
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id)
);

create index idx_micro_projects_company on micro_projects (company_id, status);

create table if not exists micro_project_proposals (
  id varchar(255) not null,
  project_id varchar(255) not null,
  user_id varchar(255) not null,
  message varchar(2000) not null,
  status varchar(16) not null,
  proposed_at timestamp not null,
  decided_at timestamp,
  primary key (id)
);

create index idx_micro_project_proposals_project on micro_project_proposals (project_id);
create index idx_micro_project_proposals_user on micro_project_proposals (user_id);
