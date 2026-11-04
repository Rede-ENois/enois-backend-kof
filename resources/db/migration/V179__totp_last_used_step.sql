-- Last accepted TOTP time step per user: a code is accepted once, never again inside its window.
-- Existing rows get null (no step used yet), so nobody with 2FA enabled is affected.
alter table user_two_factor_secrets add column if not exists totp_last_step bigint null;
