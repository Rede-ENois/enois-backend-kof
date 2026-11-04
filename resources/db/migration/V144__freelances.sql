-- Freelances: trabalho pontual com escopo fechado. Tabela própria, separada de vagas
-- (sem nível, local ou vaga externa). Valor é uma faixa em milésimos de faísca e prazo é data.
create table if not exists freelances (
  id varchar(255) not null,
  user_id varchar(255) not null,
  title varchar(200) not null,
  scope varchar(4000) not null,
  budget_min int not null,
  budget_max int not null,
  deadline date not null,
  status varchar(16) not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  key idx_freelances_status_created (status, created_at),
  key idx_freelances_user (user_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
