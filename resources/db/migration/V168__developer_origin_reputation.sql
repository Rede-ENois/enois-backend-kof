-- Reputação da origem de terceiro: o backend derruba automaticamente quem acumula recusas
-- (401/403/429) na janela configurada. blocked=true tira a origem da allowlist na hora.
alter table developer_origins add column blocked boolean not null default false;
alter table developer_origins add column blocked_reason varchar(200) null;
alter table developer_origins add column blocked_at timestamp null;
alter table developer_origins add column blocked_until timestamp null;
alter table developer_origins add column strikes int not null default 0;
