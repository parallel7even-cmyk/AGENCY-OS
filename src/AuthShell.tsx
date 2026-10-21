import { useEffect, useState, type FormEvent } from 'react'
import type { Session } from '@supabase/supabase-js'
import { ArrowRight, Building2, LockKeyhole, LogOut, Plus, ShieldCheck } from 'lucide-react'
import App from './App'
import { isSupabaseConfigured, supabase } from './lib/supabase'

type Workspace = { id: string; name: string; slug: string; role: string }

export default function AuthShell() {
  const [session, setSession] = useState<Session | null>(null)
  const [ready, setReady] = useState(!isSupabaseConfigured)
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [workspaces, setWorkspaces] = useState<Workspace[]>([])
  const [workspaceReady, setWorkspaceReady] = useState(false)
  const [workspaceName, setWorkspaceName] = useState('')
  const [selectedWorkspace, setSelectedWorkspace] = useState<Workspace | null>(null)

  useEffect(() => {
    if (!supabase) return
    supabase.auth.getSession().then(({ data, error: sessionError }) => {
      if (sessionError) setError(sessionError.message)
      setSession(data.session)
      setReady(true)
    })
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
      if (!nextSession) { setWorkspaces([]); setWorkspaceReady(false); setSelectedWorkspace(null) }
    })
    return () => data.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!supabase || !session) return
    let cancelled = false
    async function loadWorkspaces() {
      setWorkspaceReady(false)
      const { data: memberships, error: membershipError } = await supabase!
        .from('memberships').select('organization_id, role').eq('user_id', session!.user.id)
      if (cancelled) return
      if (membershipError) { setError(membershipError.message); setWorkspaceReady(true); return }
      const ids = (memberships ?? []).map(item => item.organization_id)
      if (!ids.length) { setWorkspaces([]); setWorkspaceReady(true); return }
      const { data: organizations, error: orgError } = await supabase!
        .from('organizations').select('id, name, slug').in('id', ids)
      if (cancelled) return
      if (orgError) setError(orgError.message)
      const roles = new Map((memberships ?? []).map(item => [item.organization_id, item.role]))
      setWorkspaces((organizations ?? []).map(org => ({ ...org, role: String(roles.get(org.id) ?? 'member') })))
      setWorkspaceReady(true)
    }
    void loadWorkspaces()
    return () => { cancelled = true }
  }, [session])

  if (!isSupabaseConfigured || !supabase) return import.meta.env.PROD ? <ConfigurationRequired /> : <App />
  if (!ready) return <div className="auth-screen"><div className="auth-card">Loading secure session…</div></div>
  if (!session) return <AuthForm mode={mode} setMode={setMode} busy={busy} setBusy={setBusy} error={error} setError={setError} message={message} setMessage={setMessage} />
  if (!workspaceReady) return <div className="auth-screen"><div className="auth-card">Loading your workspaces…</div></div>
  if (!selectedWorkspace) return <WorkspacePicker workspaces={workspaces} workspaceName={workspaceName} setWorkspaceName={setWorkspaceName} busy={busy} setBusy={setBusy} error={error} setError={setError} onSelect={setSelectedWorkspace} />

  return <><div className="auth-session-bar"><span><ShieldCheck size={15}/> {selectedWorkspace.name} · {session.user.email} <b>Cloud data · workspace isolated</b></span><button onClick={() => { void supabase!.auth.signOut() }}><LogOut size={14}/> Sign out</button></div><App organizationId={selectedWorkspace.id} userId={session.user.id} role={selectedWorkspace.role} userEmail={session.user.email ?? undefined} workspaceName={selectedWorkspace.name} workspaces={workspaces} onWorkspaceChange={(workspace) => setSelectedWorkspace(workspace)} onSignOut={() => { void supabase!.auth.signOut() }} /></>
}

function ConfigurationRequired() {
  return <div className="auth-screen"><section className="auth-card" role="alert"><div className="auth-brand"><div className="auth-mark">P<span>7</span></div><div><b>PARALLEL SEVEN</b><small>AGENCY OPERATING SYSTEM</small></div></div><h1>Workspace configuration required.</h1><p>This deployment is missing its Supabase environment variables. For safety, demo data is disabled in production.</p><p className="auth-footnote">Set <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code> in your hosting provider, then redeploy.</p></section></div>
}

function AuthForm({ mode, setMode, busy, setBusy, error, setError, message, setMessage }: {
  mode: 'signin' | 'signup'; setMode: (mode: 'signin' | 'signup') => void; busy: boolean; setBusy: (value: boolean) => void;
  error: string; setError: (value: string) => void; message: string; setMessage: (value: string) => void;
}) {
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!supabase) return
    setBusy(true); setError(''); setMessage('')
    const form = new FormData(event.currentTarget)
    const email = String(form.get('email') || '').trim()
    const password = String(form.get('password') || '')
    const displayName = String(form.get('displayName') || '').trim()
    const result = mode === 'signin'
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({ email, password, options: { data: { display_name: displayName } } })
    setBusy(false)
    if (result.error) setError(result.error.message)
    else if (mode === 'signup' && !result.data.session) setMessage('Check your email to confirm your account, then sign in.')
    else setMessage(mode === 'signup' ? 'Account created.' : 'Signed in.')
  }
  return <div className="auth-screen"><form className="auth-card" onSubmit={submit}>
    <div className="auth-brand"><div className="auth-mark">P<span>7</span></div><div><b>PARALLEL SEVEN</b><small>AGENCY OPERATING SYSTEM</small></div></div>
    <div className="auth-eyebrow"><LockKeyhole size={14}/> SECURE WORKSPACE ACCESS</div>
    <h1>{mode === 'signin' ? 'Welcome back.' : 'Create your account.'}</h1><p>Access your agency workspace with a verified account.</p>
    {mode === 'signup' && <label className="auth-field"><span>Your name</span><input name="displayName" autoComplete="name" required placeholder="Full name"/></label>}
    <label className="auth-field"><span>Email address</span><input name="email" type="email" autoComplete="email" required placeholder="you@company.com"/></label>
    <label className="auth-field"><span>Password</span><input name="password" type="password" autoComplete={mode === 'signin' ? 'current-password' : 'new-password'} minLength={8} required placeholder="At least 8 characters"/></label>
    {error && <div className="auth-error" role="alert">{error}</div>}{message && <div className="auth-message" role="status">{message}</div>}
    <button className="auth-submit" disabled={busy}>{busy ? 'Please wait…' : mode === 'signin' ? 'Sign in' : 'Create account'} <ArrowRight size={16}/></button>
    <button className="auth-switch" type="button" onClick={() => { setMode(mode === 'signin' ? 'signup' : 'signin'); setError(''); setMessage('') }}>{mode === 'signin' ? 'New to Parallel Seven? Create an account' : 'Already have an account? Sign in'}</button>
    <div className="auth-footnote">Sign-up creates a user account. A workspace owner must invite team members and client users after workspace setup.</div>
  </form></div>
}

function WorkspacePicker({ workspaces, workspaceName, setWorkspaceName, busy, setBusy, error, setError, onSelect }: {
  workspaces: Workspace[]; workspaceName: string; setWorkspaceName: (value: string) => void; busy: boolean; setBusy: (value: boolean) => void;
  error: string; setError: (value: string) => void; onSelect: (workspace: Workspace) => void;
}) {
  async function createWorkspace(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!supabase) return
    setBusy(true); setError('')
    const form = new FormData(event.currentTarget)
    const name = String(form.get('workspaceName') || '').trim()
    const slug = name.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 50)
    const { data, error: rpcError } = await supabase.rpc('create_organization', { org_name: name, org_slug: slug })
    setBusy(false)
    if (rpcError) { setError(rpcError.message); return }
    const { data: org, error: selectError } = await supabase.from('organizations').select('id,name,slug').eq('id', data).single()
    if (selectError || !org) { setError(selectError?.message ?? 'Workspace created. Refresh to select it.'); return }
    onSelect({ ...org, role: 'owner' })
  }
  return <div className="auth-screen"><div className="auth-card">
    <div className="auth-brand"><div className="auth-mark"><Building2 size={18}/></div><div><b>YOUR WORKSPACE</b><small>MULTI-AGENCY ACCESS</small></div></div>
    <h1>Choose your workspace.</h1><p>Each agency has isolated data, team roles, and divisions.</p>
    {workspaces.map(workspace => <button className="workspace-choice" key={workspace.id} onClick={() => onSelect(workspace)}><span><b>{workspace.name}</b><small>{workspace.slug} · {workspace.role}</small></span><ArrowRight size={16}/></button>)}
    <form onSubmit={createWorkspace} className="workspace-create"><label className="auth-field"><span>{workspaces.length ? 'Create another agency workspace' : 'Create your first agency workspace'}</span><input name="workspaceName" value={workspaceName} onChange={e => setWorkspaceName(e.target.value)} required minLength={2} maxLength={120} placeholder="e.g. Parallel Seven"/></label>
      {error && <div className="auth-error" role="alert">{error}</div>}<button className="auth-submit" disabled={busy || !workspaceName.trim()}>{busy ? 'Creating…' : 'Create workspace'} <Plus size={16}/></button>
    </form><div className="auth-footnote">New workspaces receive Creative, Media, Studios, and Labs divisions. Slugs must be unique across the platform.</div>
  </div></div>
}
