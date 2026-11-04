-- Verificacao de identidade CIVIL (distinta de e-mail/2FA): so guarda estado e metadados minimos.
-- Nenhum documento, biometria, CPF ou payload do provedor e persistido aqui.
create table identity_verifications (
  id varchar(255) not null,
  user_id varchar(255) not null,
  provider varchar(64),
  state varchar(32) not null,
  attempt_id varchar(255),
  reason_code varchar(64),
  started_at timestamp,
  completed_at timestamp,
  expires_at timestamp,
  last_validated_at timestamp,
  consent_version varchar(64),
  updated_at timestamp not null,
  primary key (id)
);

alter table identity_verifications add constraint uk_identity_verifications_user unique (user_id);
create index idx_identity_verifications_state on identity_verifications (state);
