-- Loja de cosméticos (plano C3): a moldura de avatar EQUIPADA. A posse vive no ledger
-- (ref idempotente por usuário+item); aqui só o que está em uso. Sem FK (collation).
alter table users add column if not exists avatar_frame varchar(40) null;
