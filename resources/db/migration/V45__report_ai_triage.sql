-- Palpite estruturado do agente de IA (triagem): guardado como JSON para o painel admin.
-- NAO e prova nem executa acao: so orientacao para a revisao humana.
alter table reports add column ai_triage text;
alter table reports add column ai_triaged_at timestamp;
