-- O refresh token tem validade propria (30 dias) e precisa ser validado por ela. Antes, a sessao
-- so guardava a expiracao do access token (60 min) e o refresh morria junto com ele, forcando o
-- usuario a logar de novo. Sessoes antigas ficam com o fallback = expires_at.
alter table auth_sessions add column refresh_expires_at timestamp;

update auth_sessions set refresh_expires_at = expires_at where refresh_expires_at is null;
