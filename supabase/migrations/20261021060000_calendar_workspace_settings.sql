create table public.calendar_events (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null check(char_length(trim(title)) between 1 and 180), description text not null default '',
 event_type text not null default 'meeting' check(event_type in ('meeting','deadline','milestone','review','production')),
 starts_at timestamptz not null, ends_at timestamptz, project_id uuid, client_id uuid, location text not null default '',
 is_client_visible boolean not null default false, created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(organization_id,id),
 foreign key(organization_id,project_id) references public.projects(organization_id,id) on delete set null (project_id),
 foreign key(organization_id,client_id) references public.clients(organization_id,id) on delete set null (client_id),
 check(ends_at is null or ends_at>=starts_at)
);
create index calendar_events_org_start_idx on public.calendar_events(organization_id,starts_at);
alter table public.calendar_events enable row level security;
create policy calendar_events_select on public.calendar_events for select to authenticated using(public.has_org_role(organization_id,array['owner','admin','manager','member']::public.membership_role[]) or (is_client_visible and client_id is not null and public.is_client_for(organization_id,client_id)));
create policy calendar_events_insert on public.calendar_events for insert to authenticated with check(public.has_org_role(organization_id,array['owner','admin','manager','member']::public.membership_role[]) and created_by=auth.uid());
create policy calendar_events_update on public.calendar_events for update to authenticated using(public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[])) with check(public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create policy calendar_events_delete on public.calendar_events for delete to authenticated using(public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create trigger calendar_events_updated_at before update on public.calendar_events for each row execute procedure public.set_updated_at();
alter table public.invoices add column if not exists gst_mode text not null default 'cgst_sgst' check(gst_mode in ('cgst_sgst','igst','none'));
create table public.workspace_settings (
 organization_id uuid primary key references public.organizations(id) on delete cascade,
 legal_name text not null default 'Parallel Seven', billing_email text not null default '', phone text not null default '',
 website text not null default '', address text not null default '', gstin text not null default '', invoice_prefix text not null default 'P7',
 default_gst_rate numeric(5,2) not null default 18 check(default_gst_rate between 0 and 100),
 default_currency char(3) not null default 'INR', bank_name text not null default '', bank_branch text not null default '', account_name text not null default '', account_number text not null default '', ifsc_code text not null default '', signature_name text not null default '', invoice_footer text not null default 'Thank you for your business.', updated_at timestamptz not null default now()
);
alter table public.workspace_settings enable row level security;
create policy workspace_settings_select on public.workspace_settings for select to authenticated using(public.is_org_member(organization_id));
create policy workspace_settings_insert on public.workspace_settings for insert to authenticated with check(public.has_org_role(organization_id,array['owner','admin']::public.membership_role[]));
create policy workspace_settings_update on public.workspace_settings for update to authenticated using(public.has_org_role(organization_id,array['owner','admin']::public.membership_role[])) with check(public.has_org_role(organization_id,array['owner','admin']::public.membership_role[]));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('agency-assets','agency-assets',false,52428800,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','application/pdf']) on conflict(id) do nothing;
