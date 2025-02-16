-- Drop existing schemas if they exist
drop schema if exists realtime cascade;
drop schema if exists _realtime cascade;

-- Create realtime schema
create schema if not exists realtime;
alter schema realtime owner to postgres;

-- Set up permissions
grant usage on schema realtime to postgres, supabase_admin, dashboard_user;
grant all privileges on schema realtime to postgres, supabase_admin, dashboard_user;

-- Create extensions table
create table if not exists realtime.extensions (
    id bigint primary key generated always as identity,
    tenant_external_id text not null references realtime.tenants(external_id),
    type text not null,
    settings jsonb not null default '{}'::jsonb,
    inserted_at timestamp(0) without time zone not null default now(),
    updated_at timestamp(0) without time zone not null default now()
);

-- Insert default extension for ArivantOne
insert into realtime.extensions (tenant_external_id, type, settings)
values ('ArivantOne', 'postgres_cdc_rls', '{}'::jsonb)
on conflict do nothing;

-- Set search path
alter database realtime set search_path to realtime,public;

-- Create tenant configuration
create table if not exists realtime.tenants (
    id uuid primary key not null,
    name text,
    external_id text,
    jwt_secret text,
    max_concurrent_users integer not null default 200,
    inserted_at timestamp(0) without time zone not null,
    updated_at timestamp(0) without time zone not null,
    max_events_per_second integer not null default 100,
    postgres_cdc_default text default 'postgres_cdc_rls'::text,
    max_bytes_per_second integer not null default 100000,
    max_channels_per_client integer not null default 100,
    max_joins_per_second integer not null default 500,
    suspend boolean default false,
    jwt_jwks jsonb,
    notify_private_alpha boolean default false,
    private_only boolean not null default false
);

-- Add unique index on external_id
create unique index if not exists tenants_external_id_index on realtime.tenants(external_id);

-- Insert ArivantOne tenant
insert into realtime.tenants (
    id,
    name,
    external_id,
    jwt_secret,
    max_concurrent_users,
    inserted_at,
    updated_at,
    max_events_per_second,
    postgres_cdc_default,
    max_bytes_per_second,
    max_channels_per_client,
    max_joins_per_second,
    suspend,
    notify_private_alpha,
    private_only
) values (
    gen_random_uuid(),
    'ArivantOne',
    'ArivantOne',
    current_setting('realtime.jwt_secret', true),
    200,
    now(),
    now(),
    100,
    'postgres_cdc_rls',
    100000,
    100,
    500,
    false,
    false,
    false
)
on conflict (external_id) do update
set jwt_secret = excluded.jwt_secret,
    updated_at = now();
