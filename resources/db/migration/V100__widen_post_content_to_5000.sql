-- O PostContentLimits (que o front espelha) aceita até 5.000 caracteres (TUTORIAL; PROJECT e NEWS
-- 2.000; OPPORTUNITY 1.500), mas a coluna parou no V32 em varchar(1200): a validação passava e o
-- INSERT estourava com "Data too long for column 'content'" no MariaDB de produção. O H2 em
-- MODE=MySQL não enforce o tamanho, então a suíte não via. A coluna passa a guardar o maior limite
-- anunciado (5.000); quem manda no teto por tipo continua sendo o PostContentLimits.
alter table posts modify column content varchar(5000) not null;
