-- Punição de usuário por votação de moderadores (pedido da Mel, 2026-10-19).
--
-- Regra: só a partir de 10 moderadores ativos. A proposta é aplicada quando mais de 50% dos
-- moderadores ativos concorda (arredondado para cima). Antes disso, só admin pune diretamente.
--
-- Sem FK para users/moderator_applications de propósito: o collation de `users` difere do default
-- do banco e a FK derrubaria a migração (errno 150). O vínculo é por id.

create table if not exists moderator_sanction_proposals (
	id varchar(64) not null,
	target_user_id varchar(64) not null,
	target_username varchar(120) not null,
	sanction_type varchar(20) not null,
	reason varchar(2000) not null,
	proposer_id varchar(64) not null,
	status varchar(20) not null,
	required_votes int not null,
	created_at timestamp not null,
	decided_at timestamp null,
	primary key (id),
	key idx_sanction_proposal_status (status, created_at),
	key idx_sanction_proposal_target (target_user_id, status)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create table if not exists moderator_sanction_votes (
	id varchar(64) not null,
	proposal_id varchar(64) not null,
	moderator_id varchar(64) not null,
	vote varchar(20) not null,
	note varchar(1000) null,
	created_at timestamp not null,
	primary key (id),
	unique key uk_sanction_vote (proposal_id, moderator_id),
	key idx_sanction_vote_proposal (proposal_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
