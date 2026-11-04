-- Menções de um post agendado: quem é marcado com @ recebe a notificação quando o post
-- REALMENTE entra no ar (não na hora de agendar). CSV de ids, como as demais listas.
alter table scheduled_posts add column if not exists mentioned_ids text;
