-- O post agendado leva consigo o assunto que o autor declarou (post avulso): quando o worker
-- publica, o post entra classificado, sem perder a classificação por passar pela fila.
-- Post agendado para COMUNIDADE não usa este campo (herda o dela — recusado se preenchido).
alter table scheduled_posts add column if not exists topic varchar(40);
