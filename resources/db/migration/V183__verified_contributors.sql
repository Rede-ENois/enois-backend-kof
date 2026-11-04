-- Contribuintes verificados pelo GitHub: a candidatura passa a guardar a conta do Énóis que a
-- enviou e a origem. Candidaturas da landing continuam com user_id nulo (público, sem conta).
alter table contributor_applications add column if not exists user_id varchar(64) null;
alter table contributor_applications add column if not exists source varchar(24) not null default 'LANDING';

-- Uma confirmação por conta verificada; NULL não colide (várias candidaturas públicas).
create unique index uk_contributor_applications_user on contributor_applications (user_id);
