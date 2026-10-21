# Parallel Seven mobile foundation

Expo / React Native app foundation for the shared web-and-mobile product. Includes a responsive agency home screen and Supabase email/password sign-in and sign-up. Organization switching and cloud-backed project/task/approval CRUD are the next integration steps.

## Setup

```bash
cd mobile
npm install
```

Create `mobile/.env` with the Supabase project URL and publishable/anon key:

```bash
EXPO_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
```

Then run `npm start`. Use Expo Go or a development build for device testing. Never put a Supabase service-role key in a client app.
