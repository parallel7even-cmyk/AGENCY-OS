# Parallel Seven Agency OS — release status

## Target backend
- Supabase project: `P7even`
- Project ref: `zvigtdsjctvofclobdxp`
- Region: `ap-south-1` (Mumbai)
- Browser client uses `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (publishable/anon key only; never use a service-role key in frontend variables).

## Applied and verified on the target project
- 17 public application tables exist and have row-level security enabled.
- Organization membership, profile, division, client, project, task, lead, asset, approval, activity, automation-rule, invoice, invoice-item, payment, calendar and workspace settings tables are present.
- Organization-scoped storage bucket and storage policies were added.
- Invoice draft creation RPC validates workspace finance permissions and input and creates the invoice and first line item atomically.
- Tenant-consistency foreign keys were added for invoice/client/payment/calendar relations.
- Public execution was revoked from internal security-definer helper functions; role-check functions remain callable to signed-in users for RLS policy evaluation. Supabase advisor still reports warnings for callable security-definer functions; these require review rather than claiming a clean security audit.

## Important unverified items
- Full `npm install` timed out in this environment because the package registry could not be reached. `npm run build` has **not** passed here; TypeScript errors without installed React/Vite dependencies are not a valid build result.
- No browser end-to-end tests were run against a live authenticated session.
- No hosting deployment has been made and no custom domain is configured.
- Production code now fails closed to a configuration screen when Supabase environment variables are absent; it does not silently show demo data in production.
- Team invitations/role management UI is not implemented.
- Asset upload and approval workflows are not fully implemented in the UI.
- Automation rules are stored as configuration only; no worker, scheduler or email delivery is implemented.
- Confirm the project's Supabase Auth URL allow-list, email confirmation and password recovery settings before launch.
- Validate tax invoice treatment and accounting requirements with a qualified professional.

## Deployment checklist (must pass before launch)
1. Install dependencies in a network-enabled environment and generate/commit the package lockfile.
2. Run `npm ci`, `npm run build`, lint/type checks, and browser tests.
3. Set `VITE_SUPABASE_URL=https://zvigtdsjctvofclobdxp.supabase.co` and `VITE_SUPABASE_ANON_KEY` to the P7even publishable key in hosting environment variables.
4. Configure Supabase Auth Site URL and redirect allow-list for the production domain.
5. Test signup, confirmation, sign-in, sign-out, workspace creation, cross-tenant isolation, role permissions, CRUD, invoice totals/payments, print/PDF and calendar operations.
6. Review Supabase security/performance advisors and verify storage policies against expected asset path convention (`<organization-uuid>/...`).
7. Deploy to staging first, run smoke tests, then promote to production.
8. Configure backups, monitoring, incident contact and a rollback path.

Do not describe this release candidate as production-ready until the checks above are completed.
