-- Campos personalizados de candidatura e a resposta do candidato.
--
-- Quem publica a vaga monta o formulario: quantos campos quiser, cada um obrigatorio ou opcional.
-- O `label` e copiado para a resposta no momento do envio, para o historico nao mudar se o autor
-- editar a vaga depois. `candidate_snapshot` guarda o perfil do candidato como estava na inscricao
-- (reputacao, tempo de experiencia, verificacao) — o empregador precisa saber quem se candidatou
-- naquele momento, nao como a pessoa esta hoje.
--
-- As duas tabelas sao colecoes dos proprios agregados (campos da vaga, respostas da candidatura),
-- entao a chave primaria e composta e nao ha entidade separada. Mesmos cuidados das migracoes
-- anteriores: `if not exists` e sem FK entre tabelas de collation diferente.
create table if not exists job_application_fields (
  job_id varchar(255) not null,
  id varchar(255) not null,
  label varchar(160) not null,
  field_type varchar(16) not null,
  required boolean not null default false,
  position int not null default 0,
  primary key (job_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- application_id e bigint porque job_applications.id e bigint (a colecao pertence a essa linha).
create table if not exists job_application_answers (
  application_id bigint not null,
  field_id varchar(255) not null,
  label varchar(160) not null,
  answer_value varchar(2000) not null,
  position int not null default 0,
  primary key (application_id, field_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

alter table job_applications add column if not exists message varchar(2000) null;
alter table job_applications add column if not exists candidate_snapshot varchar(4000) null;