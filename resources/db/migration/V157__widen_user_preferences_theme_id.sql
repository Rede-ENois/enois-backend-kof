-- theme_id precisa caber o id de um tema publicado na galeria da comunidade.
--
-- Os temas hardcoded da colecao tem slug curto ('aero-glass', 'caravana-do-vento'), e os 32
-- caracteres originais chegavam. Um tema da galeria nasce de "theme_" + UUID sem tracos: 38.
-- Sem alargar, a preferencia da conta aceitava o tema na validacao e morria no INSERT.
--
-- Renumerada para V157 ao integrar com a main: V153-V156 ja estao ocupados.
-- Mantem a coluna nullable: V108__personalization passou theme_id a null para que limpar o tema
-- volte ao padrao da marca sem destruir as outras preferencias. Só alarga o tamanho.
alter table user_preferences modify theme_id varchar(64) null;
