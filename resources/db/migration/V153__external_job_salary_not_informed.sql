-- "A vaga não informa salário": os agregadores já listam vagas sem faixa, e quem cadastra
-- pela comunidade agora pode declarar isso em vez de deixar o campo em branco sem explicação.
alter table external_jobs add column if not exists salary_not_informed boolean not null default false;
