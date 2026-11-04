-- O auto-report de seguranca (fases 1-3) denuncia com reporter "system" — e a FK de reporter_id
-- so aceita usuarios reais. A denúncia automatica deixa de ter FK, seguindo o mesmo padrao
-- deliberado das outras tabelas do feed ("sem FK de proposito", licao de collation da V33/V52).
-- Quem le resolve: o painel mostra o nome pelo id e "system" vira "Segurança automática".
alter table reports drop constraint fk_reports_reporter;
