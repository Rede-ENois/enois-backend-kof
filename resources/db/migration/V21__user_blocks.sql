-- Bloqueio entre usuarios: o bloqueado desaparece para quem bloqueou (e vice-versa).
--
-- Vale para sempre, nao e uma denuncia temporaria: por isso a linha nao tem status nem expira.
-- A tabela e separada de user_connections de proposito — bloquear nao e uma conexao removida, e
-- um corte que precisa sobreviver a qualquer tentativa nova de contato.
--
-- `if not exists` + sem FK, igual as V18/V19/V20: o DDL do MariaDB nao e transacional e reaplicar
-- com seguranca evita travar o rollout.
create table if not exists user_blocks (
  id bigint not null auto_increment,
  blocker_id varchar(255) not null,
  blocked_id varchar(255) not null,
  created_at timestamp not null,
  primary key (id),
  constraint uk_user_blocks_pair unique (blocker_id, blocked_id),
  key idx_user_blocks_blocker (blocker_id),
  key idx_user_blocks_blocked (blocked_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;