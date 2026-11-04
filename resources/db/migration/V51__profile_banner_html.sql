-- Capa do perfil tambem aceita HTML/CSS (a "capa customizada"), com o mesmo tratamento da bio:
-- sanitizado no servidor com allowlist de tags/atributos e CSS, e renderizado num quadro isolado no
-- front, ocupando o mesmo espaço que a imagem ocuparia. As duas formas convivem — quando existe a
-- versao em HTML, e ela que aparece.
alter table users add column banner_html longtext;
