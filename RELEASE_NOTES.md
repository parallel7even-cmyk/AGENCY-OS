# Release candidate update — P7even

- Bound the source package to the intended Supabase project `zvigtdsjctvofclobdxp` through environment example values.
- Added production fail-closed behavior when Supabase configuration is missing; local demo mode remains available in development only.
- Added baseline hosting response headers and disallowed search indexing for the private workspace app.
- Added database relation integrity, invoice atomicity, and private storage policy changes on the target project.
- Expanded deployment notes to clearly separate verified changes from unverified build, end-to-end tests, hosting, and unfinished modules.

This is a release candidate, not a certified production release. Full dependency installation/build and live E2E tests remain blocked by network access in the current environment.
