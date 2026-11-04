-- "Habilidades" e um campo de texto livre no perfil (a pessoa separa por virgula): 120 caracteres
-- por item cortava quem escreve uma frase de habilidades em vez de tags soltas. O campo aceita 800
-- caracteres, entao cada item precisa caber nisso tambem.
alter table user_skills modify column skill varchar(800) not null;
