-- Comunidade sem descrição: o campo passa a ser OPCIONAL.
--
-- "Sem descrição" é um estado legítimo (a comunidade pode nascer só com nome e ganhar texto
-- depois), e não se inventa descrição para preencher. As linhas existentes ficam intactas — o
-- MODIFY só afrouxa a restrição. Idempotente por natureza: reaplicar o mesmo MODIFY não muda nada.
alter table communities modify column description varchar(2000) null;
