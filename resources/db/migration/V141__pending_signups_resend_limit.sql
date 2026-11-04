-- Limite de reenvio do link de confirmacao no cadastro de DUAS ETAPAS.
--
-- O fluxo de conta ja criada conta os envios (email_verification_tokens) e recusa o 4o dentro da
-- janela. O cadastro de duas etapas nao tinha contador: o reenvio do link pendente saia SEM teto,
-- e dava para spammar a caixa de quem se cadastrou. Aqui entra o mesmo limite (3 envios por
-- hora, contando o e-mail do cadastro).
--
-- resend_count conta os envios dentro da janela; last_sent_at e quando foi o ultimo (a janela
-- reinicia depois de 1h sem envio). Colunas novas com valor padrao: pendente antigo entra na
-- janela como se nunca tivesse recebido nada.
alter table pending_signups add column if not exists resend_count int not null default 0;
alter table pending_signups add column if not exists last_sent_at timestamp null;
