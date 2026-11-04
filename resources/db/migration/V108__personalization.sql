-- Extensão de personalização (plano master, fases A e B):
-- 1. Classificação de assuntos nas publicações: a taxonomia real do produto é a das
--    comunidades (TECNOLOGIA, ENGHARIA→ENGENHARIA, DESIGN, PRODUTO, LIDERANCA, CARREIRA,
--    FREELANCE, OUTROS). Post publicado numa comunidade herda o tópico dela na criação;
--    post solto pode ter tópico opcional. NULL = sem classificação (nunca é bloqueado).
-- 2. Preferências de personalização na tabela que já existe (uma linha por usuário):
--    listas validadas no backend contra a taxonomia/módulos reais — sem JSON livre.
--    O theme_id vira nullable: limpar o tema não pode destruir as outras preferências
--    que agora moram na mesma linha.
-- Uma instrução por coluna: o H2 de teste não aceita múltiplos adds na mesma linha.
alter table posts add column if not exists topic varchar(40) null;
create index if not exists idx_posts_topic on posts (topic);

alter table user_preferences modify theme_id varchar(32) null;
alter table user_preferences add column if not exists liked_topics varchar(400) null;
alter table user_preferences add column if not exists blocked_topics varchar(400) null;
alter table user_preferences add column if not exists disabled_modules varchar(400) null;
