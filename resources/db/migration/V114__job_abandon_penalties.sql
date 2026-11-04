-- Item 7 do backlog: penalidade por excluir vaga sem dar retorno.
--
-- Excluir uma vaga com candidatos ainda em APPLIED (nunca respondidos) fica registrado aqui:
-- uma linha por vaga excluída (job_id é a chave — regravar a mesma exclusão não contaga duas
-- vezes) e o componente de integridade da credibilidade desconta com teto. Quem respondeu
-- todas as candidaturas (IN_REVIEW/ADVANCED/NOT_SELECTED) não é penalizado: a regra é
-- "excluir sem responder reduz credibilidade; com respostas, não".
create table if not exists job_abandon_penalties (
  job_id varchar(255) not null,
  user_id varchar(255) not null,
  unanswered int not null,
  recorded_at timestamp not null,
  primary key (job_id)
);
create index if not exists idx_job_abandon_user on job_abandon_penalties (user_id);
