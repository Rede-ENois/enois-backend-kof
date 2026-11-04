-- Retorno do empregador para o candidato: o motivo (quando ele reprova) e quando a candidatura foi
-- revisada. Sem isso o candidato recebe "nao selecionado" sem saber o que faltou — e o aviso vira
-- um "obrigado por participar" que nao ajuda ninguem a melhorar.
alter table job_applications add column feedback varchar(1000) null;
alter table job_applications add column reviewed_at timestamp null;
