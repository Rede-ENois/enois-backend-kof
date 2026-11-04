-- Curriculo do perfil: o arquivo (PDF) vive no storage de midia, como avatar e emblema; aqui ficam
-- o endereco e o nome original do arquivo — o nome e o que faz o download sair como
-- "curriculo-ana.pdf" em vez de um id do CDN.
--
-- NAO entra na projecao publica do perfil: curriculo tem telefone, endereco e historico — e dado da
-- pessoa, entregue por ela quando quiser (no envio da candidatura), nunca publicado na pagina.
alter table users add column resume_url varchar(500) null;
alter table users add column resume_name varchar(200) null;
