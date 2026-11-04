-- Mídia nas mensagens diretas (até 4 por mensagem). Sem FK: ids de mídia são opacos para a
-- conversa e a leitura resolve no catálogo de mídia. Coluna única com ids separados por vírgula
-- porque a ordenação importa e o volume por mensagem é pequeno.
alter table messages add column if not exists media_ids varchar(1000) null;
