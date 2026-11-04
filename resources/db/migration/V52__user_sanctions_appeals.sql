-- Sancoes de moderacao (restricao automatica pos-triagem de IA; ban so por recurso negado)
-- e recursos. Sem FK de proposito: a armadilha de collation do MariaDB em FKs ja derrubou rollout.
create table user_sanctions (
  id varchar(255) not null,
  user_id varchar(255) not null,
  report_id varchar(255),
  type varchar(20) not null,
  reason varchar(2000),
  status varchar(20) not null,
  created_at timestamp not null,
  removed_at timestamp,
  removed_by varchar(255),
  primary key (id)
);

create index idx_user_sanctions_user on user_sanctions (user_id, status);

create table appeals (
  id varchar(255) not null,
  sanction_id varchar(255) not null,
  user_id varchar(255) not null,
  message varchar(2000) not null,
  status varchar(20) not null,
  created_at timestamp not null,
  reviewed_by varchar(255),
  reviewed_at timestamp,
  primary key (id)
);

create index idx_sanction_appeals_status on appeals (status, created_at);
create index idx_appeals_user on appeals (user_id);
