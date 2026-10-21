-- Remove redundant unique constraints after confirming equivalent constraints remain.
-- Keep clients_organization_id_id_key because projects and invoices reference it.
ALTER TABLE public.clients DROP CONSTRAINT IF EXISTS clients_org_id_unique;
-- Keep workspace_settings_organization_id_key as the unique constraint on organization_id.
ALTER TABLE public.workspace_settings DROP CONSTRAINT IF EXISTS workspace_settings_organization_unique;
