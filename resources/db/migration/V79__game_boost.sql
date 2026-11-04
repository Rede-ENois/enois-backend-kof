-- Destaque pago (G2 do plano): o criador impulsiona o PRÓPRIO jogo por faíscas —
-- nunca alcance de terceiros, só a ordem do catálogo por um tempo.
alter table games add column if not exists boost_until timestamp null;
