-- Énóis Grupos: espaços privados com feed próprio, tópicos, ingresso controlado e moderação
-- local subordinada à plataforma.
--
-- Tabelas PRÓPRIAS de propósito: nada aqui é compartilhado com communities nem com posts. O
-- isolamento é estrutural — o feed principal, a busca pública e os perfis não têm como alcançar
-- conteúdo de grupo nem por engano de consulta, porque ele mora em outra tabela. A reutilização
-- acontece nos serviços transversais (mídia, notificações, denúncias, AutoMod, auditoria).
--
-- SEM chave estrangeira DE PROPÓSITO (a armadilha de collation do MariaDB, errno 150, derrubava o
-- boot: o users de produção tem collation diferente das tabelas novas). Integridade na aplicação,
-- como no resto do banco; os índices ficam para as junções. Unicidade de (grupo, usuário) no
-- membro e uma solicitação pendente por pessoa continuam garantidas pelos índices únicos.
--
-- Idempotente: `if not exists` em tudo, porque uma migração que recria objeto existente derruba o
-- boot e trava o rollout em silêncio.

create table if not exists groups (
  id varchar(255) not null,
  slug varchar(80) not null,
  name varchar(120) not null,
  description varchar(600),
  topic varchar(40),
  avatar varchar(500),
  banner varchar(500),
  banner_html longtext,
  -- OPEN: entra e vira membro na hora. APPROVAL: pedido pendente até uma decisão.
  join_mode varchar(16) not null default 'APPROVAL',
  -- ACTIVE | RESTRICTED | SUSPENDED | CLOSED (o significado operacional vive no domínio).
  status varchar(16) not null default 'ACTIVE',
  owner_id varchar(255) not null,
  member_count int not null default 0,
  post_count int not null default 0,
  created_at timestamp not null,
  updated_at timestamp not null,
  suspended_at timestamp,
  primary key (id),
  unique key uk_groups_slug (slug),
  key idx_groups_status_created (status, created_at),
  key idx_groups_owner (owner_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create table if not exists group_members (
  id varchar(255) not null,
  group_id varchar(255) not null,
  user_id varchar(255) not null,
  -- OWNER | ADMIN | MODERATOR | MEMBER
  role varchar(16) not null default 'MEMBER',
  joined_at timestamp not null,
  primary key (id),
  unique key uk_group_members_group_user (group_id, user_id),
  key idx_group_members_user (user_id, joined_at),
  key idx_group_members_group (group_id, role)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

-- Pedido de ingresso. `pending_slot` vale o user_id enquanto PENDING e vira NULL quando o pedido
-- é decidido: o índice único (group_id, pending_slot) então garante UMA solicitação pendente por
-- pessoa e grupo — sem ele, duas requisições simultâneas criariam dois pedidos e a aprovação de
-- um deixaria o outro vivo. Índice único ignora NULL, então o histórico pode ter várias linhas
-- decididas.
create table if not exists group_join_requests (
  id varchar(255) not null,
  group_id varchar(255) not null,
  user_id varchar(255) not null,
  message varchar(500),
  -- PENDING | APPROVED | REJECTED | CANCELLED
  status varchar(16) not null default 'PENDING',
  pending_slot varchar(255),
  created_at timestamp not null,
  decided_by varchar(255),
  decided_at timestamp,
  primary key (id),
  unique key uk_group_join_pending (group_id, pending_slot),
  key idx_group_join_group_status (group_id, status, created_at),
  key idx_group_join_user (user_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

-- Tópicos internos do grupo.
create table if not exists group_topics (
  id varchar(255) not null,
  group_id varchar(255) not null,
  name varchar(80) not null,
  description varchar(300),
  position int not null default 0,
  -- OPEN | ARCHIVED (arquivado não recebe publicação nova; o histórico continua legível)
  status varchar(16) not null default 'OPEN',
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  unique key uk_group_topics_group_name (group_id, name),
  key idx_group_topics_group_position (group_id, position)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create table if not exists group_posts (
  id varchar(255) not null,
  group_id varchar(255) not null,
  topic_id varchar(255) not null,
  author_id varchar(255) not null,
  content varchar(1200) not null,
  -- Mídia é o serviço transversal de sempre (o mesmo media_id do feed): não há tabela de anexo.
  media_ids varchar(1000) not null default '',
  -- PUBLISHED | REMOVED
  status varchar(16) not null default 'PUBLISHED',
  pinned boolean not null default false,
  reactions int not null default 0,
  comments int not null default 0,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  unique key uk_group_posts_id_topic (id, topic_id),
  key idx_group_posts_feed (group_id, status, created_at),
  key idx_group_posts_topic (topic_id, status, created_at),
  key idx_group_posts_author (author_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create table if not exists group_post_comments (
  id varchar(255) not null,
  post_id varchar(255) not null,
  group_id varchar(255) not null,
  author_id varchar(255) not null,
  parent_id varchar(255),
  content varchar(1200) not null,
  -- PUBLISHED | REMOVED
  status varchar(16) not null default 'PUBLISHED',
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  key idx_group_comments_post (post_id, status, created_at),
  key idx_group_comments_author (author_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

-- Uma reação por pessoa por publicação (o feed principal é assim; o grupo segue a mesma régua).
create table if not exists group_post_reactions (
  id varchar(255) not null,
  post_id varchar(255) not null,
  user_id varchar(255) not null,
  type varchar(24) not null,
  created_at timestamp not null,
  primary key (id),
  unique key uk_group_reactions_post_user (post_id, user_id),
  key idx_group_reactions_user (user_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;
