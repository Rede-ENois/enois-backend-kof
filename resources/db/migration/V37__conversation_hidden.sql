-- "Apagar para mim": esconde a conversa so para quem pediu (o outro participante mantem).
-- Nao remove a conversa nem as mensagens; e reversivel/nao afeta terceiros.
alter table conversation_participants add column hidden_at timestamp;
