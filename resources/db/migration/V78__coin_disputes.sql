-- Contestação de transferência (golpe): a vítima contesta dentro da janela; a moderação
-- decide PELO MESMO FLUXO de denúncia. Verdadeira → a transferência é REVERTIDA (espelho
-- no ledger) e o golpista restrito; falsa → quem contestou é punido. Append-only sempre.
create table if not exists coin_disputes (
  id varchar(255) not null,
  entry_ref varchar(255) not null,
  sender_id varchar(255) not null,
  receiver_id varchar(255) not null,
  amount bigint not null,
  reason varchar(400) not null,
  description varchar(1000) not null,
  state varchar(16) not null,
  report_id varchar(255),
  review_note varchar(500),
  reviewed_by varchar(255),
  reviewed_at timestamp,
  created_at timestamp not null,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_coin_disputes_state on coin_disputes (state, created_at);
create index if not exists idx_coin_disputes_sender on coin_disputes (sender_id, state);
create index if not exists idx_coin_disputes_receiver on coin_disputes (receiver_id, state);
