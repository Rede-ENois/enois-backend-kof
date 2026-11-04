-- Migração oportunista de mídia (ImageKit -> S3):
-- 1) claim no ASSET: garante que só UMA réplica copia cada mídia por vez (com expiração de claim
--    velho para o caso de o pod morrer no meio da cópia).
alter table media_assets add column if not exists s3_claimed_at timestamp null;

-- 2) referências por URL (avatar, banner, capas de comunidade/empresa/evento/jogo, logo de vaga,
--    página de criador): a cópia do OBJETO é idempotente e compartilhada; a troca das referências
--    acontece depois, por UPDATE condicional (só onde a URL antiga ainda está lá).
create table if not exists media_url_migrations (
  url_hash varchar(64) not null,
  source_url varchar(1000) not null,
  status varchar(16) not null,
  s3_url varchar(1000),
  attempts int not null default 0,
  last_error varchar(500),
  claimed_at timestamp null,
  updated_at timestamp not null,
  primary key (url_hash)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_media_url_migrations_status on media_url_migrations (status, updated_at);
