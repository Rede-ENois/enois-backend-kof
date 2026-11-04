-- Cosméticos criados pela comunidade: o manifest é declarativo e só fica visível depois da moderação.
create table if not exists profile_cosmetics (
  id varchar(64) not null,
  creator_id varchar(64) not null,
  kind varchar(32) not null,
  name varchar(80) not null,
  description varchar(300),
  manifest_json longtext not null,
  license varchar(40) not null,
  rights_confirmed boolean not null,
  status varchar(32) not null,
  version int not null,
  reported int not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  key idx_profile_cosmetics_creator (creator_id, created_at),
  key idx_profile_cosmetics_status (status, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
