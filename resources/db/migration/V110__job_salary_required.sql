-- Item 5 do backlog: vaga com valor OBRIGATÓRIO, período, faixa e descrição.
--
-- A vaga nova passa a declarar o valor de forma estruturada: `salary_min` é o mínimo
-- obrigatório (> 0), `salary_max` é a faixa opcional (nunca abaixo do mínimo) e
-- `salary_period` diz se o valor é por hora, dia, mês ou ano. `description` é o texto
-- que explica a vaga (obrigatório na criação e edição de vaga nova).
--
-- Vagas antigas continuam como estão: o texto livre em `salary` (já nulo no schema desde
-- a V5) continua sendo a exibição de quem nunca declarou o valor estruturado.
alter table jobs add column if not exists description longtext;
alter table jobs add column if not exists salary_min numeric(12,2);
alter table jobs add column if not exists salary_max numeric(12,2);
alter table jobs add column if not exists salary_period varchar(10);
