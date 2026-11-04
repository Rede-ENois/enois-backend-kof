-- Single-use tracking of the signup challenge shared by every pod (it used to live in each pod's
-- memory). New table; no existing rows are touched. Rows expire with the challenge (5 minutes) and
-- are purged opportunistically by the application.
create table if not exists signup_challenge_nonces (
  nonce varchar(64) not null,
  expires_at timestamp not null,
  primary key (nonce),
  key idx_signup_challenge_nonces_expires (expires_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
