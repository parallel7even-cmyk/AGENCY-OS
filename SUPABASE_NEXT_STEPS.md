# Supabase connection and status

This project is currently configured for the intended Supabase project **P7even**.

- Project ref: `zvigtdsjctvofclobdxp`
- API URL: `https://zvigtdsjctvofclobdxp.supabase.co`
- Region: Mumbai (`ap-south-1`)
- Tables created: 17 public application tables, all with RLS enabled
- Private Storage bucket: `agency-assets`

The `.env.example` contains the publishable browser key for this project. Publishable keys are designed for client-side use; never put a service-role key in a frontend environment file.

## Important deployment notes

- The live schema was provisioned directly in this Supabase project and then aligned with the frontend's expected columns and policies. Do not blindly run `supabase db push` with the older migration history in this package against this live project.
- Before production use, configure Supabase Auth Site URL and redirect URLs for the final deployment domain.
- Review Supabase security advisories for authenticated `SECURITY DEFINER` helper functions. The current helper functions are used by RLS policies; do not revoke their execution grants without replacing and testing dependent policies.
- Supabase's security advisor reported leaked-password protection is disabled. Enable it in Auth password settings after confirming the desired signup/password policy.
- The performance advisor reported duplicate unique indexes on `clients` and `workspace_settings`, missing foreign-key indexes, and RLS policy expressions that can be optimized. Review constraint dependencies and query patterns before applying database changes.
- A Vercel deployment URL has been provided, but successful production behavior has not yet been verified end-to-end. GitHub Actions currently runs `npm install` and `npm run build`; add and commit a lockfile before switching CI to `npm ci`.
- Before launch, verify the Vercel Production environment has `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`, then test signup/sign-in, workspace creation, role isolation, and CRUD behavior against the deployed URL.
- Supabase Auth Site URL and redirect URLs must include the final deployment domain.
- Automation rules are stored as configuration; there is no event worker/scheduler executing them yet. Asset upload/approval UI and team invitations are not fully implemented.
