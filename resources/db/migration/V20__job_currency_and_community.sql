-- Moeda da faixa salarial + registro do aceite das regras da comunidade ao publicar a vaga.
--
-- `currency` guarda o codigo ISO (BRL/USD/EUR). O valor em `salary` fica sem simbolo: quem publica
-- escreve "R$ 8.000" ou "$8,000" e a aplicacao normaliza na gravacao e remonta o texto na exibicao,
-- para a mesma vaga nunca aparecer com dois simbolos diferentes.
--
-- Mesmos cuidados das V18/V19: `if not exists` (seguro para reaplicar, ja que uma falha no meio deixa
-- a versao marcada como FAILED) e sem FK.
--
-- Vagas antigas ficam em BRL e seguem legiveis: a exibicao tambem remove simbolo solto do valor.
alter table jobs add column if not exists currency varchar(3) not null default 'BRL';
alter table jobs add column if not exists community_agreed_at timestamp null;