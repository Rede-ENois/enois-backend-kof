-- Bloqueio de IP pela moderacao: um IP na lista nao cria conta, nao loga, nao emite sessao.
-- O admin pega o IP na listagem "IPs deste usuario" (registrado no login) e bloqueia de la.
create table if not exists blocked_ips (
  id varchar(255) not null,
  ip varchar(64) not null,
  reason varchar(2000),
  created_by varchar(255),
  created_at timestamp not null,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create unique index uk_blocked_ips_ip on blocked_ips (ip);

-- De onde cada conta logou: o painel mostra os IPs recentes de um usuario para o admin decidir
-- bloquear. Sem FK de proposito (mesma licao de collation das outras tabelas de rede).
alter table auth_sessions add column ip varchar(64);
