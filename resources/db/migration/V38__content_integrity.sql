-- Integridade de conteudo: deteccao de copia/copypasta, credibilidade por evento e penalidades.
--
-- Regras de armazenamento (privacidade/LGPD): a tabela de fingerprint guarda apenas DERIVADOS do
-- texto (hash normalizado, simhash, bandas de busca e assinatura minhash) — nunca o texto. Quando
-- uma correspondencia precisa ser mostrada, o conteudo original e lido da propria tabela de posts ou
-- comentarios, respeitando as permissoes que ja existem. Nada aqui permite reconstruir um texto.
create table content_fingerprints (
  id varchar(255) not null,
  content_kind varchar(16) not null,
  content_ref_id varchar(255) not null,
  author_id varchar(255) not null,
  content_format varchar(16) not null,
  normalized_hash varchar(64) not null,
  simhash bigint not null,
  band_low integer not null,
  band_high integer not null,
  token_count integer not null,
  minhash varchar(512) not null,
  community_id varchar(255),
  rules_version varchar(32) not null,
  state varchar(16) not null,
  created_at timestamp not null,
  primary key (id)
);
-- igualdade normalizada (copia literal, mesmo com pontuacao/espaco/unicode diferentes)
create index idx_fingerprints_hash on content_fingerprints (normalized_hash);
-- bandas do simhash: busca de candidatos sem varrer a tabela inteira
create index idx_fingerprints_band_low on content_fingerprints (band_low);
create index idx_fingerprints_band_high on content_fingerprints (band_high);
create index idx_fingerprints_author on content_fingerprints (author_id, created_at);
create index idx_fingerprints_ref on content_fingerprints (content_kind, content_ref_id);

-- Uma analise por conteudo e versao de regras: reprocessar (retry, evento reentregue, edicao
-- reanalisada) nao cria linha nova nem penalidade nova.
create table content_analyses (
  id varchar(255) not null,
  content_kind varchar(16) not null,
  content_ref_id varchar(255) not null,
  author_id varchar(255) not null,
  content_format varchar(16) not null,
  category varchar(32) not null,
  similarity double not null,
  copy_evidence double not null,
  ai_reuse_signal double not null,
  severity varchar(16) not null,
  decision varchar(32) not null,
  review_status varchar(16) not null,
  matched_ref_id varchar(255),
  matched_author_id varchar(255),
  matched_similarity double,
  indicators varchar(1000) not null,
  rationale varchar(1000) not null,
  rules_version varchar(32) not null,
  created_at timestamp not null,
  reviewed_by varchar(255),
  reviewed_at timestamp,
  review_note varchar(500),
  primary key (id)
);
alter table content_analyses add constraint uk_analyses_content_rules unique (content_kind, content_ref_id, rules_version);
create index idx_analyses_author on content_analyses (author_id, created_at);
create index idx_analyses_review on content_analyses (review_status, created_at);
create index idx_analyses_ref on content_analyses (content_kind, content_ref_id);

-- Infracoes confirmadas (depois de confirmadas, contam para reincidencia).
create table integrity_infractions (
  id varchar(255) not null,
  user_id varchar(255) not null,
  analysis_id varchar(255) not null,
  category varchar(32) not null,
  severity varchar(16) not null,
  status varchar(16) not null,
  confirmed_by varchar(64) not null,
  confirmed_at timestamp not null,
  reversed_at timestamp,
  reversed_by varchar(255),
  note varchar(500),
  rules_version varchar(32) not null,
  primary key (id)
);
-- Uma infracao por analise: o mesmo fato nunca conta duas vezes na reincidencia.
alter table integrity_infractions add constraint uk_infractions_analysis unique (analysis_id);
create index idx_infractions_user on integrity_infractions (user_id, status, confirmed_at);

-- Penalidades aplicadas (com prazo e motivo). Banimento so entra por revisao humana.
create table integrity_penalties (
  id varchar(255) not null,
  user_id varchar(255) not null,
  infraction_id varchar(255),
  analysis_id varchar(255),
  action varchar(32) not null,
  state varchar(16) not null,
  severity varchar(16) not null,
  starts_at timestamp not null,
  ends_at timestamp,
  decided_by varchar(64) not null,
  reason_code varchar(64) not null,
  rationale varchar(1000) not null,
  rules_version varchar(32) not null,
  reversed_at timestamp,
  reversed_by varchar(255),
  created_at timestamp not null,
  primary key (id)
);
-- Mesma analise nao gera a mesma penalidade duas vezes (retry/concorrencia/reprocessamento).
alter table integrity_penalties add constraint uk_penalties_analysis_action unique (analysis_id, action);
create index idx_penalties_user on integrity_penalties (user_id, state, ends_at);

-- Ledger de credibilidade: cada linha e um evento auditavel; o saldo e a soma dos deltas.
create table integrity_events (
  id varchar(255) not null,
  user_id varchar(255) not null,
  kind varchar(16) not null,
  points integer not null,
  reason_code varchar(64) not null,
  analysis_id varchar(255),
  infraction_id varchar(255),
  penalty_id varchar(255),
  reverses_event_id varchar(255),
  dedup_key varchar(128) not null,
  rules_version varchar(32) not null,
  created_at timestamp not null,
  primary key (id)
);
-- Idempotencia do ledger: o mesmo evento nunca e aplicado duas vezes.
alter table integrity_events add constraint uk_events_dedup unique (dedup_key);
create index idx_events_user on integrity_events (user_id, created_at);

-- Saldo materializado da credibilidade (0 a 100), recalculavel a partir dos eventos.
create table user_integrity (
  user_id varchar(255) not null,
  score integer not null,
  updated_at timestamp not null,
  last_recovery_at timestamp,
  primary key (user_id)
);

-- Contestacoes: uma por penalidade (evita flood no proprio endpoint de contestacao).
create table integrity_appeals (
  id varchar(255) not null,
  penalty_id varchar(255) not null,
  user_id varchar(255) not null,
  message varchar(1000) not null,
  status varchar(16) not null,
  created_at timestamp not null,
  decided_by varchar(255),
  decided_at timestamp,
  decision_note varchar(500),
  primary key (id)
);
alter table integrity_appeals add constraint uk_appeals_penalty unique (penalty_id);
create index idx_appeals_status on integrity_appeals (status, created_at);
