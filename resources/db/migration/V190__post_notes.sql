-- Nota de rodapé da comunidade: correção/contexto enviado por outra pessoa e aprovado pela
-- moderação antes de aparecer no post. Não é denúncia e não mexe na credibilidade de quem envia
-- enquanto está pendente/aprovada; só a nota NEGADA pesa na credibilidade (ver NotePenaltyReader).
create table if not exists post_notes (
  id varchar(64) not null,
  post_id varchar(64) not null,
  author_id varchar(64) not null,
  body varchar(500) not null,
  status varchar(20) not null,
  reviewed_by varchar(64) null,
  reviewed_at timestamp null,
  review_reason varchar(500) null,
  created_at timestamp not null,
  primary key (id),
  key idx_post_notes_post_status (post_id, status, created_at),
  key idx_post_notes_author_status (author_id, status)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;