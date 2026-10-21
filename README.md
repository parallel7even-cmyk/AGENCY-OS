# Parallel Seven Agency OS — Core CRUD milestone

Responsive web application for the Parallel Seven creative agency operating system. Brand direction: cinematic black surfaces with orange-red accents and the supplied Parallel Seven logo.

## Implemented in this milestone
- Existing dashboard, project workspace, client directory, task delivery list, and lead pipeline.
- Create, read, edit, and delete actions for projects, clients, tasks, and leads.
- Task completion toggles and lead-stage updates.
- Workspace-scoped Supabase reads/writes when authenticated through the existing workspace picker.
- Organization IDs are attached to writes and all queries are scoped to the selected workspace; Supabase row-level security remains the final access-control boundary.
- Local demo mode with browser persistence when Supabase environment variables are absent.
- Search across projects, clients, tasks, and leads; responsive styling and micro-interactions.
- Delete controls respect the current membership role in the UI; database RLS is authoritative.

## Run on macOS
Requires Node.js 20+.

```bash
npm install
npm run dev
```

Open the local URL printed by Vite, usually `http://localhost:5173`.

## Enable cloud data
1. Create a Supabase project.
2. In Supabase SQL Editor, apply `supabase/migrations/202610160001_initial_multitenant_schema.sql`.
3. Copy `.env.example` to `.env.local` and set:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY` (publishable/anon key only)
4. Restart the Vite dev server, create an account, and create/select a workspace.

Never put a Supabase service-role key in browser environment variables. It bypasses row-level security.

## Current limitations
- Cloud sync requires the user to configure a Supabase project and apply the migration; this repository does not include credentials or a deployed backend.
- This milestone has not been verified against a live Supabase instance, and a production build could not be run in this environment because package installation was unavailable.
- Tasks must belong to an existing project in cloud mode. Project-client linking is based on selecting an existing client company.
- File uploads, invitations, real-time subscriptions, email notifications, finance, and native mobile data sync remain future work.


## Finance / Supabase setup
See `SUPABASE_NEXT_STEPS.md` and migration `202610160002_finance_invoices.sql`. The migration prepares secure invoice, line-item, and payment tables. The Finance UI is not yet connected to those tables, so this is database groundwork, not a claim of live billing.


## Vercel deployment

This is a React + Vite app. Import the repository into Vercel and keep the defaults in `vercel.json` (`npm run build`, output `dist`). Set these environment variables for Production, Preview, and Development:

- `VITE_SUPABASE_URL` — your Supabase project URL.
- `VITE_SUPABASE_ANON_KEY` — the publishable/anon client key only. Never use a service-role key in a browser app.

The app uses Supabase Auth and RLS for tenant-scoped cloud data. On the existing Parallel Seven `Agency OS` project, the schema has already been applied directly; do not re-run the historical `20261016...` migration files against that database. The `20261021...` file is for provisioning a fresh database after the initial and finance migrations.

Before a public production launch, complete a full `npm run build`, test sign-up/email confirmation and password sign-in on the deployed domain, review Supabase security advisories, configure the Auth Site URL and redirect allow-list for the Vercel domain, and test each role with separate accounts. Automation rules are currently saved configuration; they do not execute background actions yet. Asset upload/approval UI and team invitation UI are not yet connected.


## Release checklist (required before production)

1. Copy `.env.example` to `.env.local` and set the `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` values for the intended Supabase project. Publishable/anon keys are designed for browser use; never place a service-role key in Vite variables.
2. In a network-enabled environment, run `npm install`, then `npm run build`. Fix all TypeScript/build errors before deployment.
3. Configure Supabase Auth Site URL and allowed redirect URLs for the actual production domain. Test signup, confirmation, sign-in, sign-out, workspace creation, and access from two separate users.
4. Test row-level security with two organizations and verify no user can read or write another organization's records.
5. Test client/project/task/lead CRUD, invoice totals and GST treatment, payment recording, calendar CRUD, and settings persistence. Test invalid inputs and failed network requests.
6. Configure the production host and domain, deploy, then run desktop/mobile smoke tests.
7. Team invites, asset/approval UI, and automation execution are not implemented in this release candidate; do not represent these as functional.

### Important live database note

The P7even database was aligned directly through Supabase management. The checked-in initial migrations predate that live setup and are not a safe blind `supabase db push` against the existing project. Reconcile/baseline migration history before using Supabase CLI migrations on P7even.
