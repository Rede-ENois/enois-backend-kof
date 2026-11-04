-- Cotação de REFERÊNCIA da faísca em BRL (plano C7/Fase 5): o preço que a plataforma
-- usa para remuneração de criador e exibe no monitor — NÃO é câmbio (isso é Fase 6/7,
-- só com jurídico). Cada mudança vira uma linha: o histórico alimenta a mini bolsa.
create table if not exists coin_rate_history (
  id varchar(255) not null,
  brl_cents bigint not null,
  note varchar(200),
  effective_at timestamp not null,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_coin_rate_time on coin_rate_history (effective_at);
