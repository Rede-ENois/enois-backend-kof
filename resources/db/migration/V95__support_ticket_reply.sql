-- Resposta do suporte no painel do moderador (pedido da Mel, 2026-10-19).
-- O texto fica registrado no ticket (auditoria) e é enviado ao e-mail de contato; a conclusão
-- continua sendo o status CLOSED. Sem FK para users pelo mesmo motivo das outras migrações.
alter table support_requests add column if not exists admin_reply varchar(4000) null;
alter table support_requests add column if not exists replied_by varchar(64) null;
alter table support_requests add column if not exists replied_at timestamp null;
