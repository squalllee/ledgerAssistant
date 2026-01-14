create table public.transactions (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null, -- Associated user for RLS
  account_id uuid null,
  credit_card_id uuid null, -- Added for credit card payment tracking
  type text not null,
  amount numeric not null,
  note text null,
  transaction_date timestamp with time zone null default now(),
  created_at timestamp with time zone null default now(),
  receipt_url text null,
  constraint transactions_pkey primary key (id),
  constraint transactions_account_id_fkey foreign KEY (account_id) references accounts (id) on delete set null,
  constraint transactions_credit_card_id_fkey foreign KEY (credit_card_id) references credit_cards (id) on delete set null,
  constraint transactions_type_check check (
    (
      type = any (array['income'::text, 'expense'::text])
    )
  )
) TABLESPACE pg_default;

-- user_id moved to line items

create index IF not exists idx_transactions_date on public.transactions using btree (transaction_date) TABLESPACE pg_default;


create table public.transaction_line_items (
  id uuid not null default gen_random_uuid (),
  transaction_id uuid not null,
  user_id uuid not null, -- The owner of the transaction
  family_member_id uuid null, -- Specific family member if split
  name text not null,
  amount numeric not null,
  quantity integer null default 1,
  created_at timestamp with time zone null default now(),
  category_id uuid null,
  title text null,
  constraint transaction_line_items_pkey primary key (id),
  constraint transaction_line_items_category_id_fkey foreign KEY (category_id) references categories (id) on delete set null,
  constraint transaction_line_items_transaction_id_fkey foreign KEY (transaction_id) references transactions (id) on delete CASCADE,
  constraint transaction_line_items_user_id_fkey foreign KEY (user_id) references profiles (id) on delete CASCADE,
  constraint transaction_line_items_family_member_id_fkey foreign KEY (family_member_id) references family_members (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_line_items_transaction_id on public.transaction_line_items using btree (transaction_id) TABLESPACE pg_default;


create table public.profiles (
  id uuid not null,
  username text null,
  avatar_url text null,
  updated_at timestamp with time zone null default now(),
  birthday date null,
  phone text null,
  monthly_limit numeric null default 10000,
  constraint profiles_pkey primary key (id)
) TABLESPACE pg_default;


create table public.family_members (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  name text not null,
  created_at timestamp with time zone null default now(),
  constraint family_members_pkey primary key (id),
  constraint family_members_user_id_fkey foreign KEY (user_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;


create table public.credit_cards (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  card_name text not null,
  billing_day integer not null,
  created_at timestamp with time zone null default now(),
  constraint credit_cards_pkey primary key (id),
  constraint credit_cards_user_id_fkey foreign KEY (user_id) references profiles (id) on delete CASCADE,
  constraint credit_cards_billing_day_check check (
    (
      (billing_day >= 1)
      and (billing_day <= 31)
    )
  )
) TABLESPACE pg_default;

create table public.categories (
  id uuid not null default gen_random_uuid (),
  name text not null,
  icon text null,
  color text null,
  created_at timestamp with time zone null default now(),
  constraint categories_pkey primary key (id),
  constraint categories_name_key unique (name)
) TABLESPACE pg_default;

create table public.accounts (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  name text not null,
  balance numeric null default 0,
  created_at timestamp with time zone null default now(),
  constraint accounts_pkey primary key (id),
  constraint accounts_user_id_fkey foreign KEY (user_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_accounts_user_id on public.accounts using btree (user_id) TABLESPACE pg_default;