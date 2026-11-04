-- Segundo fator delegado ao provedor de identidade (Google/Apple).
--
-- Quando alguem entra por um provedor que confirma o e-mail, o proprio provedor ja responde por duas
-- etapas (senha dele + os fatores que ele exige). Guardamos o instante para a conta constar como
-- verificada/2FA sem inventar um TOTP que nao existe — os metodos que NOS desafiamos no login seguem
-- sendo apenas os ativados pelo usuario (aplicativo ou codigo por e-mail).
--
-- Mesmos cuidados das migracoes anteriores: `if not exists` e sem FK.
alter table users add column if not exists federated_second_factor_at timestamp null;