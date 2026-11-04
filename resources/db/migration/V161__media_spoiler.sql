alter table posts add column if not exists media_spoiler boolean not null default false;
alter table comments add column if not exists media_spoiler boolean not null default false;
alter table messages add column if not exists media_spoiler boolean not null default false;
