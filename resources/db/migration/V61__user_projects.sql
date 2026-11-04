-- Cards de projeto no perfil: stack, link do repositório, status e o diário de
-- evolução. Quando o autor prefere, o card inteiro vira HTML próprio (sanitizado).
-- stack: tecnologias separadas por linha; diary: JSON [{date, text}].
create table user_projects (
  id varchar(40) not null,
  user_id varchar(255) not null,
  position int not null,
  title varchar(120) not null,
  stack varchar(400) not null,
  repo_url varchar(500),
  status varchar(40),
  diary text,
  html longtext,
  created_at timestamp not null,
  updated_at timestamp not null,
  constraint pk_user_projects primary key (id)
);
create index idx_user_projects_user on user_projects (user_id, position);
