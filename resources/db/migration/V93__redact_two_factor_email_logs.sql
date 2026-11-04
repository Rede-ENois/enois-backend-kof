-- Segurança (pedido da Mel, 2026-10-19): o log de e-mails guarda apenas metadados, mas o
-- assunto do e-mail de 2FA carregava o código. Novos envios usam assunto genérico e o
-- EmailService redige qualquer assunto TWO_FACTOR; esta migração limpa o histórico já gravado.
update email_log
set subject = 'Seu código de acesso (redigido)'
where kind = 'TWO_FACTOR';
