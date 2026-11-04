-- "Habilidades" e "Objetivos" sao campos de texto livre no perfil (separados por virgula) e o teto
-- de cada item estava curto demais para quem escreve uma frase em vez de etiquetas soltas. Os dois
-- passam a caber 1600 caracteres — o mesmo teto do campo no front — e o item pode ocupar o campo
-- inteiro. V43 (e nao editar a V42, ja aplicada em producao): migracao aplicada nao se reescreve.
alter table user_skills modify column skill varchar(1600) not null;
alter table user_goals modify column goal varchar(1600) not null;
