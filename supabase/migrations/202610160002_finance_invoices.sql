-- Parallel Seven Finance v1: invoices, line items, payment ledger, tenant-safe RLS
create table if not exists public.invoices (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 client_id uuid not null,
 invoice_number text not null,
 issue_date date not null default current_date,
 due_date date,
 status text not null default 'draft' check (status in ('draft','sent','partially_paid','paid','overdue','cancelled')),
 currency char(3) not null default 'INR',
 discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
 gst_rate numeric(5,2) not null default 0 check (gst_rate >= 0 and gst_rate <= 100),
 gst_mode text not null default 'cgst_sgst' check (gst_mode in ('cgst_sgst','igst','none')),
 notes text not null default '',
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique (organization_id, invoice_number), unique (organization_id,id),
 foreign key (organization_id,client_id) references public.clients(organization_id,id)
);
create table if not exists public.invoice_items (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 invoice_id uuid not null,
 description text not null check (char_length(trim(description)) > 0),
 quantity numeric(12,2) not null default 1 check (quantity > 0),
 unit_price numeric(12,2) not null default 0 check (unit_price >= 0),
 sort_order integer not null default 0,
 created_at timestamptz not null default now(),
 foreign key (organization_id,invoice_id) references public.invoices(organization_id,id) on delete cascade
);
create table if not exists public.invoice_payments (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 invoice_id uuid not null,
 amount numeric(12,2) not null check (amount > 0),
 payment_date date not null default current_date,
 method text not null default 'bank_transfer',
 reference text not null default '',
 notes text not null default '',
 recorded_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 foreign key (organization_id,invoice_id) references public.invoices(organization_id,id) on delete cascade
);
create index if not exists invoices_org_date_idx on public.invoices(organization_id,issue_date desc);
create index if not exists invoice_items_invoice_idx on public.invoice_items(organization_id,invoice_id);
create index if not exists invoice_payments_invoice_idx on public.invoice_payments(organization_id,invoice_id,payment_date desc);
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.invoice_payments enable row level security;
-- Invoice financial data is restricted to owner/admin/manager. Clients do not see invoices until a dedicated client billing policy is added.
create policy invoices_select_finance on public.invoices for select to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create policy invoices_insert_finance on public.invoices for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]) and created_by=auth.uid());
create policy invoices_update_finance on public.invoices for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[])) with check (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create policy invoices_delete_finance on public.invoices for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin']::public.membership_role[]));
create policy invoice_items_select_finance on public.invoice_items for select to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create policy invoice_items_insert_finance on public.invoice_items for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create policy invoice_items_update_finance on public.invoice_items for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[])) with check (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create policy invoice_items_delete_finance on public.invoice_items for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create policy invoice_payments_select_finance on public.invoice_payments for select to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]));
create policy invoice_payments_insert_finance on public.invoice_payments for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager']::public.membership_role[]) and recorded_by=auth.uid());
create policy invoice_payments_update_finance on public.invoice_payments for update to authenticated using (public.has_org_role(organization_id,array['owner','admin']::public.membership_role[])) with check (public.has_org_role(organization_id,array['owner','admin']::public.membership_role[]));
create policy invoice_payments_delete_finance on public.invoice_payments for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin']::public.membership_role[]));
