-- Migracao ImageKit -> S3 em duas fases, sem ninguem perder midia.
--
-- Fase 1 (copia): o worker baixa o original do ImageKit, sobe para o S3, confere pelo HeadObject e
-- grava s3_cdn_url/migrated_at. O cdn_url (o que o app le) NAO muda nesta fase — o objeto antigo
-- continua no ImageKit. Fase 2 (flip): so quando a URL publica do S3 responder, o cdn_url passa a
-- apontar para o S3; se nao responder, a linha fica como esta.
--
-- storage_provider: de qual provedor o cdn_url atual aponta. Novos uploads em modo s3 nascem S3.
alter table media_assets add column if not exists storage_provider varchar(16) not null default 'IMAGEKIT';
alter table media_assets add column if not exists s3_cdn_url varchar(1024) null;
alter table media_assets add column if not exists s3_migrated_at timestamp null;
alter table media_assets add column if not exists s3_migration_attempts int not null default 0;
alter table media_assets add column if not exists s3_last_error varchar(300) null;

create index if not exists idx_media_assets_s3_copy
  on media_assets (storage_provider, s3_migrated_at, s3_migration_attempts);
