-- Limpeza dos servicos que ficaram orfaos: oferta (e pedido) de uma conta que NAO EXISTE MAIS
-- na base. Aconteceu com os servicos de teste que rodaram contra a API de producao: as contas de
-- teste sumiram depois e as ofertas ficaram no catalogo, aparecendo para todo mundo sem ninguem
-- atras (nem nome, nem foto, nem chat com o prestador).
--
-- A conta que a pessoa apaga pelo app e ANONIMIZADA (o registro continua, o nome vira
-- "removed-..."), entao a oferta dela continua no catalogo — e esta migracao nao mexe nessas.
-- Aqui so sai o que ficou sem dono: oferta cujo vendedor nao esta em `users`, pedido cujo
-- pedinte nao esta em `users` e as propostas do pedido removido.
--
-- Idempotente: rodar duas vezes nao muda nada (o segundo delete nao acha linha).
delete from service_listings
where seller_id not in (select id from users);

delete from service_proposals
where request_id not in (select id from service_requests);

delete from service_requests
where requester_id not in (select id from users);
