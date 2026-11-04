-- Fase 14 (desempenho): os feeds por identidade profissional filtram author_identity + status
-- e ordenam por created_at. O índice simples em author_identity ainda faria o MariaDB ordenar
-- em memória; o composto cobre filtro e ordenação. Os índices do perfil social (author_id,
-- status, created_at) já existem desde a V1 e continuam servindo o perfil profissional.
create index if not exists idx_posts_identity_status_created on posts (author_identity, status, created_at);
