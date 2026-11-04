-- Cadastro em duas etapas: o e-mail e verificado ANTES de a conta existir.
--
-- O POST /auth/signup (com captcha) guarda aqui o que a pessoa preencheu — nome, data de
-- nascimento e o HASH da senha — e envia o link de confirmacao. A conta (users + user_credentials)
-- so nasce quando o link e usado. Assim um cadastro em massa com e-mail invalido nao cria linha
-- nenhuma na base e o ataque perde o efeito de poluir contas.
--
-- Um pendente por e-mail (unique): refazer o cadastro substitui o anterior e invalida o link velho.
-- token_hash guarda o SHA-256 do token enviado por e-mail (o token cru nunca vai para o banco).
create table if not exists pending_signups (
  id varchar(64) not null,
  email varchar(255) not null,
  name varchar(120) not null,
  birth_date date not null,
  password_hash varchar(255) not null,
  token_hash varchar(64) not null,
  expires_at timestamp not null,
  created_at timestamp not null,
  primary key (id),
  unique key ux_pending_signups_email (email),
  unique key ux_pending_signups_token (token_hash),
  key idx_pending_signups_expires (expires_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
