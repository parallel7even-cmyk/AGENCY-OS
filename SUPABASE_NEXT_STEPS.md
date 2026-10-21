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
- Review the remaining Supabase security advisories for authenticated `SECURITY DEFINER` helper functions. Those helper functions are used by row-level security policies, so do not revoke their authenticated execution grants without replacing the policies appropriately.
- The app is not deployed yet. Run `npm install` and `npm run build` in a network-enabled environment, test signup/login and RLS behavior, then deploy the `dist` output to a static host.
- Automation rules are stored as configuration; there is no event worker/scheduler executing them yet. Asset upload/approval UI and team invitations are not fully implemented.
