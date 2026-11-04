-- Painel de moderadores (pedido da Mel, 2026-10-19).
--
-- Candidatura: quem tem credibilidade > 500 pode se candidatar; um admin aprova. A aprovacao
-- vigente e o papel de moderador (nao existe coluna de role em users). Revogar = REVOKED.
-- Voto: um moderador vota PUNISH/DISMISS por denuncia; o quorum e decidido no servidor.
--
-- Sem FK para users de proposito: o collation de `users` difere do default do banco e a FK
-- derrubaria a migracao (errno 150). Indices por user/report fazem o trabalho.

create table if not exists moderator_applications (
	id varchar(64) not null,
	user_id varchar(64) not null,
	motivation varchar(2000) not null,
	experience varchar(2000) null,
	availability varchar(500) null,
	status varchar(20) not null,
	created_at timestamp not null,
	reviewed_by varchar(64) null,
	reviewed_at timestamp null,
	review_note varchar(1000) null,
	primary key (id),
	key idx_mod_app_user (user_id, created_at),
	key idx_mod_app_status (status, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create table if not exists moderation_votes (
	id varchar(64) not null,
	report_id varchar(64) not null,
	moderator_id varchar(64) not null,
	vote varchar(20) not null,
	note varchar(1000) null,
	created_at timestamp not null,
	updated_at timestamp not null,
	primary key (id),
	unique key uk_mod_vote (report_id, moderator_id),
	key idx_mod_vote_report (report_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
