-- Painel central de moderação (2026-10-19): categoria nos tickets de suporte e log de e-mails.
--
-- `category` separa o que é problema (BUG), conta/acesso, conteúdo, ideia e outros. O painel
-- filtra por categoria e status. Tickets antigos entram como OTHER.
--
-- `email_log` guarda METADADOS dos e-mails enviados (para quem, assunto, tipo, sucesso/falha).
-- O corpo não é gravado: o painel não vira um arquivo de mensagens pessoais.

alter table support_requests add column if not exists category varchar(24) not null default 'OTHER';

create table if not exists email_log (
	id varchar(64) not null,
	to_email varchar(180) not null,
	subject varchar(200) not null,
	kind varchar(40) not null,
	status varchar(16) not null,
	error varchar(500) null,
	created_at timestamp not null,
	primary key (id),
	key idx_email_log_created (created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
