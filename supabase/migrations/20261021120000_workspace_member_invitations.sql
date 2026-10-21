-- Workspace invitations are email-bound and expire after seven days.
create table if not exists public.workspace_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email text not null,
  role public.membership_role not null,
  client_id uuid null,
  token uuid not null unique default gen_random_uuid(),
  invited_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz null,
  constraint workspace_invitations_client_org_fk foreign key (organization_id, client_id) references public.clients(organization_id, id)
);
create index if not exists workspace_invitations_org_pending_idx on public.workspace_invitations (organization_id, created_at desc) where accepted_at is null;
alter table public.workspace_invitations enable row level security;
revoke all on public.workspace_invitations from anon, authenticated;
grant select, insert, update, delete on public.workspace_invitations to service_role;

create or replace function public.create_workspace_invitation(p_organization_id uuid, p_email text, p_role text, p_client_id uuid default null)
returns table(invitation_token uuid, invited_email text, expires_at timestamptz)
language plpgsql security definer set search_path = public, auth
as $$
declare v_role public.membership_role; v_token uuid; v_expires timestamptz;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if not exists (select 1 from public.memberships m where m.organization_id=p_organization_id and m.user_id=auth.uid() and m.role::text in ('owner','admin')) then
    raise exception 'Only workspace owners and admins can invite members';
  end if;
  if p_role not in ('admin','manager','member','client') then raise exception 'Invalid invite role'; end if;
  if trim(coalesce(p_email,'')) = '' or position('@' in p_email) < 2 then raise exception 'Enter a valid email address'; end if;
  if p_client_id is not null and not exists (select 1 from public.clients c where c.organization_id=p_organization_id and c.id=p_client_id) then raise exception 'Client record does not belong to this workspace'; end if;
  if p_role='client' and p_client_id is null then raise exception 'Choose the client record for client access'; end if;
  v_role := p_role::public.membership_role;
  insert into public.workspace_invitations(organization_id,email,role,client_id,invited_by)
  values(p_organization_id,lower(trim(p_email)),v_role,p_client_id,auth.uid())
  returning token, workspace_invitations.expires_at into v_token,v_expires;
  return query select v_token,lower(trim(p_email)),v_expires;
end; $$;

create or replace function public.accept_workspace_invitation(p_token uuid)
returns table(organization_id uuid, organization_name text, assigned_role text)
language plpgsql security definer set search_path = public, auth
as $$
declare v_inv public.workspace_invitations%rowtype; v_email text;
begin
  if auth.uid() is null then raise exception 'Sign in or create your account before accepting an invitation'; end if;
  v_email := lower(trim(coalesce(auth.jwt()->>'email','')));
  if v_email='' then raise exception 'Your account must have an email address'; end if;
  select * into v_inv from public.workspace_invitations where token=p_token and accepted_at is null and expires_at>now() for update;
  if not found then raise exception 'This invitation is invalid, expired, or already used'; end if;
  if v_inv.email<>v_email then raise exception 'Sign in with the email address that received this invitation'; end if;
  insert into public.memberships(organization_id,user_id,role,client_id,invited_by)
  values(v_inv.organization_id,auth.uid(),v_inv.role,v_inv.client_id,v_inv.invited_by)
  on conflict (organization_id,user_id) do nothing;
  update public.workspace_invitations set accepted_at=now() where id=v_inv.id;
  return query select v_inv.organization_id,o.name,v_inv.role::text from public.organizations o where o.id=v_inv.organization_id;
end; $$;
revoke all on function public.create_workspace_invitation(uuid,text,text,uuid) from public, anon;
revoke all on function public.accept_workspace_invitation(uuid) from public, anon;
grant execute on function public.create_workspace_invitation(uuid,text,text,uuid) to authenticated;
grant execute on function public.accept_workspace_invitation(uuid) to authenticated;
