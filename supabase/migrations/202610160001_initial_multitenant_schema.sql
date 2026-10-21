-- Parallel Seven Agency OS: multi-tenant foundation
-- Apply with Supabase CLI: supabase db push
create extension if not exists pgcrypto;

create type public.membership_role as enum ('owner', 'admin', 'manager', 'member', 'client');
create type public.project_status as enum ('planning', 'in_progress', 'in_review', 'blocked', 'completed', 'archived');
create type public.task_status as enum ('todo', 'in_progress', 'in_review', 'done', 'blocked');
create type public.lead_stage as enum ('new_lead', 'discovery', 'qualified', 'proposal', 'won', 'lost');
create type public.approval_status as enum ('pending', 'approved', 'changes_requested', 'rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.membership_role not null default 'member',
  client_id uuid,
  invited_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, user_id),
  check ((role = 'client' and client_id is not null) or (role <> 'client' and client_id is null))
);

create table public.divisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  slug text not null,
  description text not null default '',
  color_token text not null default 'lime',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, slug),
  unique (organization_id, id)
);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  company_name text not null,
  email text,
  phone text,
  website text,
  notes text not null default '',
  status text not null default 'active' check (status in ('prospect','active','paused','archived')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id)
);

alter table public.memberships
  add constraint memberships_client_same_org_fk
  foreign key (organization_id, client_id) references public.clients(organization_id, id)
  on delete cascade;

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  division_id uuid,
  client_id uuid,
  name text not null,
  description text not null default '',
  service_line text not null default 'Branding',
  status public.project_status not null default 'planning',
  progress integer not null default 0 check (progress between 0 and 100),
  start_date date,
  due_date date,
  is_client_visible boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, division_id) references public.divisions(organization_id, id) on delete set null (division_id),
  foreign key (organization_id, client_id) references public.clients(organization_id, id) on delete set null (client_id)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_id uuid not null,
  title text not null,
  description text not null default '',
  status public.task_status not null default 'todo',
  priority text not null default 'medium' check (priority in ('low','medium','high','urgent')),
  assignee_id uuid references public.profiles(id) on delete set null,
  due_at timestamptz,
  client_visible boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, project_id) references public.projects(organization_id, id) on delete cascade
);

create table public.leads (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  division_id uuid,
  name text not null,
  company_name text not null default '',
  email text,
  source text not null default 'manual',
  estimated_value numeric(12,2) not null default 0 check (estimated_value >= 0),
  currency char(3) not null default 'INR',
  stage public.lead_stage not null default 'new_lead',
  owner_id uuid references public.profiles(id) on delete set null,
  next_follow_up_at timestamptz,
  notes text not null default '',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, division_id) references public.divisions(organization_id, id) on delete set null (division_id)
);

create table public.assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_id uuid not null,
  uploaded_by uuid not null references public.profiles(id),
  storage_path text not null,
  file_name text not null,
  mime_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  version_number integer not null default 1 check (version_number > 0),
  client_visible boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (organization_id, project_id) references public.projects(organization_id, id) on delete cascade,
  unique (organization_id, storage_path),
  unique (organization_id, id)
);

create table public.approvals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_id uuid not null,
  asset_id uuid,
  requested_from uuid references public.profiles(id) on delete set null,
  status public.approval_status not null default 'pending',
  feedback text not null default '',
  requested_at timestamptz not null default now(),
  responded_at timestamptz,
  foreign key (organization_id, project_id) references public.projects(organization_id, id) on delete cascade,
  foreign key (organization_id, asset_id) references public.assets(organization_id, id) on delete set null (asset_id)
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  entity_type text not null,
  entity_id uuid,
  action text not null,
  summary text not null default '',
  client_visible boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  event_key text not null,
  conditions jsonb not null default '{}'::jsonb,
  actions jsonb not null default '[]'::jsonb,
  is_enabled boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index memberships_user_org_idx on public.memberships(user_id, organization_id);
create index projects_org_status_idx on public.projects(organization_id, status);
create index projects_org_client_idx on public.projects(organization_id, client_id);
create index tasks_org_project_idx on public.tasks(organization_id, project_id);
create index tasks_org_assignee_due_idx on public.tasks(organization_id, assignee_id, due_at);
create index leads_org_stage_idx on public.leads(organization_id, stage);
create index activities_org_created_idx on public.activities(organization_id, created_at desc);

-- Security-definer helpers avoid recursive RLS evaluation on memberships.
create or replace function public.try_uuid(value text)
returns uuid language plpgsql immutable security definer set search_path = public
as $$ begin return value::uuid; exception when others then return null; end; $$;

create or replace function public.is_org_member(target_org uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.memberships m where m.organization_id = target_org and m.user_id = auth.uid()) $$;

create or replace function public.has_org_role(target_org uuid, allowed_roles public.membership_role[])
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.memberships m where m.organization_id = target_org and m.user_id = auth.uid() and m.role = any(allowed_roles)) $$;

create or replace function public.is_client_for(target_org uuid, target_client uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.memberships m where m.organization_id = target_org and m.user_id = auth.uid() and m.role = 'client' and m.client_id = target_client) $$;

create or replace function public.can_access_project(target_project uuid, require_client_visible boolean default false)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.projects p
    where p.id = target_project
      and (
        public.has_org_role(p.organization_id, array['owner','admin','manager','member']::public.membership_role[])
        or (p.client_id is not null and public.is_client_for(p.organization_id, p.client_id)
            and (not require_client_visible or p.is_client_visible))
      )
  )
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, ''), '@', 1), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger p7_on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create or replace function public.create_organization(org_name text, org_slug text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare new_org_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(trim(org_name)) < 2 or char_length(trim(org_name)) > 120 then raise exception 'Invalid organization name'; end if;
  if org_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then raise exception 'Invalid organization slug'; end if;
  insert into public.organizations(name, slug, created_by) values (trim(org_name), org_slug, auth.uid()) returning id into new_org_id;
  insert into public.memberships(organization_id, user_id, role) values (new_org_id, auth.uid(), 'owner');
  insert into public.divisions(organization_id, name, slug, description, color_token) values
    (new_org_id, 'Creative', 'creative', 'Brand strategy, identity, and digital design', 'violet'),
    (new_org_id, 'Media', 'media', 'Campaigns, social content, and distribution', 'lime'),
    (new_org_id, 'Studios', 'studios', 'Photo, film, and production services', 'blue'),
    (new_org_id, 'Labs', 'labs', 'Experiments, products, and emerging technology', 'orange');
  return new_org_id;
end;
$$;

-- updated_at trigger
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public
as $$ begin new.updated_at = now(); return new; end; $$;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
create trigger organizations_updated_at before update on public.organizations for each row execute procedure public.set_updated_at();
create trigger clients_updated_at before update on public.clients for each row execute procedure public.set_updated_at();
create trigger projects_updated_at before update on public.projects for each row execute procedure public.set_updated_at();
create trigger tasks_updated_at before update on public.tasks for each row execute procedure public.set_updated_at();
create trigger leads_updated_at before update on public.leads for each row execute procedure public.set_updated_at();
create trigger automation_rules_updated_at before update on public.automation_rules for each row execute procedure public.set_updated_at();

-- Enable RLS on all tenant and user tables.
alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.memberships enable row level security;
alter table public.divisions enable row level security;
alter table public.clients enable row level security;
alter table public.projects enable row level security;
alter table public.tasks enable row level security;
alter table public.leads enable row level security;
alter table public.assets enable row level security;
alter table public.approvals enable row level security;
alter table public.activities enable row level security;
alter table public.automation_rules enable row level security;

create policy profiles_select_self_or_org on public.profiles for select to authenticated
using (id = auth.uid() or exists (select 1 from public.memberships mine join public.memberships theirs on theirs.organization_id = mine.organization_id where mine.user_id = auth.uid() and theirs.user_id = profiles.id));
create policy profiles_update_self on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy organizations_select_member on public.organizations for select to authenticated using (public.is_org_member(id));
create policy organizations_update_admin on public.organizations for update to authenticated using (public.has_org_role(id, array['owner','admin']::public.membership_role[])) with check (public.has_org_role(id, array['owner','admin']::public.membership_role[]));
-- Organization creation is intentionally via create_organization() RPC only.

create policy memberships_select_same_org on public.memberships for select to authenticated using (public.is_org_member(organization_id));
create policy memberships_insert_admin on public.memberships for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[]) and (role <> 'owner' or public.has_org_role(organization_id, array['owner']::public.membership_role[])));
create policy memberships_update_admin on public.memberships for update to authenticated using (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[])) with check (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[]) and (role <> 'owner' or public.has_org_role(organization_id, array['owner']::public.membership_role[])));
create policy memberships_delete_admin on public.memberships for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[]));

create policy divisions_select_member on public.divisions for select to authenticated using (public.is_org_member(organization_id));
create policy divisions_insert_manager on public.divisions for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[]));
create policy divisions_update_manager on public.divisions for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[])) with check (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[]));
create policy divisions_delete_admin on public.divisions for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[]));

create policy clients_select_internal_or_self on public.clients for select to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]) or public.is_client_for(organization_id, id));
create policy clients_insert_internal on public.clients for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy clients_update_internal on public.clients for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])) with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy clients_delete_admin on public.clients for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[]));

create policy projects_select_internal_or_client on public.projects for select to authenticated using (
  public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])
  or (client_id is not null and public.is_client_for(organization_id, client_id) and is_client_visible)
);
create policy projects_insert_internal on public.projects for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy projects_update_internal on public.projects for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])) with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy projects_delete_admin on public.projects for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[]));

create policy tasks_select_internal_or_visible_client on public.tasks for select to authenticated using (
  public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])
  or (client_visible and public.can_access_project(project_id, true))
);
create policy tasks_insert_internal on public.tasks for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy tasks_update_internal on public.tasks for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])) with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy tasks_delete_manager on public.tasks for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[]));

create policy leads_internal_select on public.leads for select to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy leads_internal_insert on public.leads for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy leads_internal_update on public.leads for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])) with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy leads_admin_delete on public.leads for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[]));

create policy assets_select_internal_or_visible_client on public.assets for select to authenticated using (
  public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])
  or (client_visible and public.can_access_project(project_id, true))
);
create policy assets_insert_internal on public.assets for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy assets_update_internal on public.assets for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])) with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy assets_delete_manager on public.assets for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[]));

create policy approvals_select_internal_or_client on public.approvals for select to authenticated using (
  public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])
  or public.can_access_project(project_id, true)
);
create policy approvals_insert_internal on public.approvals for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
create policy approvals_update_internal_or_client on public.approvals for update to authenticated using (
  public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])
  or public.can_access_project(project_id, true)
) with check (
  public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[])
  or public.can_access_project(project_id, true)
);
create policy approvals_delete_manager on public.approvals for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[]));

create policy activities_select_internal on public.activities for select to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','member']::public.membership_role[]));
-- Activity inserts are intentionally restricted to trusted server-side workflows and database triggers.

create policy automation_rules_select_admins on public.automation_rules for select to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[]));
create policy automation_rules_insert_admins on public.automation_rules for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[]));
create policy automation_rules_update_admins on public.automation_rules for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[])) with check (public.has_org_role(organization_id, array['owner','admin','manager']::public.membership_role[]));
create policy automation_rules_delete_admins on public.automation_rules for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']::public.membership_role[]));

-- Restrict direct helper execution to authenticated clients.
revoke all on function public.try_uuid(text) from public, anon;
revoke all on function public.is_org_member(uuid) from public, anon;
revoke all on function public.has_org_role(uuid, public.membership_role[]) from public, anon;
revoke all on function public.is_client_for(uuid, uuid) from public, anon;
revoke all on function public.can_access_project(uuid, boolean) from public, anon;
revoke all on function public.create_organization(text, text) from public, anon;
grant execute on function public.try_uuid(text) to authenticated;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.has_org_role(uuid, public.membership_role[]) to authenticated;
grant execute on function public.is_client_for(uuid, uuid) to authenticated;
grant execute on function public.can_access_project(uuid, boolean) to authenticated;
grant execute on function public.create_organization(text, text) to authenticated;
revoke execute on function public.try_uuid(text) from public, anon;
revoke execute on function public.is_org_member(uuid) from public, anon;
revoke execute on function public.has_org_role(uuid, public.membership_role[]) from public, anon;
revoke execute on function public.is_client_for(uuid, uuid) from public, anon;
revoke execute on function public.can_access_project(uuid, boolean) from public, anon;
revoke execute on function public.create_organization(text, text) from public, anon;

-- Keep the storage bucket private. Policies scope objects by organization UUID as the first path segment.
insert into storage.buckets (id, name, public, file_size_limit)
values ('agency-assets', 'agency-assets', false, 52428800)
on conflict (id) do nothing;
create policy agency_assets_read on storage.objects for select to authenticated using (
  bucket_id = 'agency-assets' and (storage.foldername(name))[1] is not null
  and public.is_org_member(public.try_uuid((storage.foldername(name))[1]))
);
create policy agency_assets_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'agency-assets' and (storage.foldername(name))[1] is not null
  and public.has_org_role(public.try_uuid((storage.foldername(name))[1]), array['owner','admin','manager','member']::public.membership_role[])
);
create policy agency_assets_update on storage.objects for update to authenticated using (
  bucket_id = 'agency-assets' and (storage.foldername(name))[1] is not null
  and public.has_org_role(public.try_uuid((storage.foldername(name))[1]), array['owner','admin','manager']::public.membership_role[])
) with check (
  bucket_id = 'agency-assets' and (storage.foldername(name))[1] is not null
  and public.has_org_role(public.try_uuid((storage.foldername(name))[1]), array['owner','admin','manager']::public.membership_role[])
);
create policy agency_assets_delete on storage.objects for delete to authenticated using (
  bucket_id = 'agency-assets' and (storage.foldername(name))[1] is not null
  and public.has_org_role(public.try_uuid((storage.foldername(name))[1]), array['owner','admin','manager']::public.membership_role[])
);
