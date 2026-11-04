-- Reverte V174: o IP de origem passa a viver no log de monitorabilidade (system_events), não no
-- log de e-mails. Dropar a coluna mantém o banco sem dados mortos; a reversão é segura porque o
-- campo foi criado nesta mesma janela de deploy.
alter table email_log drop column client_ip;
