import { useEffect, useState, type FormEvent } from 'react'
import type { Session } from '@supabase/supabase-js'
import { ArrowRight, Building2, LockKeyhole, LogOut, Plus, ShieldCheck } from 'lucide-react'
import App from './App'
import { isSupabaseConfigured, supabase } from './lib/supabase'

type Workspace = { id: string; name: string; slug: string; role: string }

export default function AuthShell() {
  const [session, setSession] = useState<Session | null>(null)
  const [ready, setReady] = useState(!isSupabaseConfigured)
  const [mode, setMode] = useState<'signin' | 'signup' | 'reset' | 'update-password'>('signin')
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
    const { data } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (event === 'PASSWORD_RECOVERY') setMode('update-password')
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
      const available = (organizations ?? []).map(org => ({ ...org, role: String(roles.get(org.id) ?? 'member') }))
      setWorkspaces(available)
      if (available.length === 1) setSelectedWorkspace(current => current ?? available[0])
      setWorkspaceReady(true)
    }
    void loadWorkspaces()
    return () => { cancelled = true }
  }, [session])

  if (!isSupabaseConfigured || !supabase) return import.meta.env.PROD ? <ConfigurationRequired /> : <App />
  if (!ready) return <div className="auth-screen"><div className="auth-card">Loading secure session…</div></div>
  if (!session || mode === 'update-password') return <AuthForm mode={mode} setMode={setMode} busy={busy} setBusy={setBusy} error={error} setError={setError} message={message} setMessage={setMessage} />
  if (!workspaceReady) return <div className="auth-screen"><div className="auth-card">Loading your workspaces…</div></div>
  if (!selectedWorkspace) return <WorkspacePicker workspaces={workspaces} workspaceName={workspaceName} setWorkspaceName={setWorkspaceName} busy={busy} setBusy={setBusy} error={error} setError={setError} onSelect={setSelectedWorkspace} />

  return <><div className="auth-session-bar"><span><ShieldCheck size={15}/> {selectedWorkspace.name} · {session.user.email} <b>Cloud data · workspace isolated</b></span><button onClick={() => { void supabase!.auth.signOut() }}><LogOut size={14}/> Sign out</button></div><App organizationId={selectedWorkspace.id} userId={session.user.id} role={selectedWorkspace.role} userEmail={session.user.email ?? undefined} workspaceName={selectedWorkspace.name} workspaces={workspaces} onWorkspaceChange={(workspace) => setSelectedWorkspace(workspace)} onSignOut={() => { void supabase!.auth.signOut() }} /></>
}

function ConfigurationRequired() {
  return <div className="auth-screen"><section className="auth-card" role="alert"><div className="auth-brand"><div className="auth-mark">P<span>7</span></div><div><b>PARALLEL SEVEN</b><small>AGENCY OPERATING SYSTEM</small></div></div><h1>Workspace configuration required.</h1><p>This deployment is missing its Supabase environment variables. For safety, demo data is disabled in production.</p><p className="auth-footnote">Set <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code> in your hosting provider, then redeploy.</p></section></div>
}

function AuthForm({ mode, setMode, busy, setBusy, error, setError, message, setMessage }: {
  mode: 'signin' | 'signup' | 'reset' | 'update-password'; setMode: (mode: 'signin' | 'signup' | 'reset' | 'update-password') => void; busy: boolean; setBusy: (value: boolean) => void;
  error: string; setError: (value: string) => void; message: string; setMessage: (value: string) => void;
}) {
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!supabase) return
    setBusy(true); setError(''); setMessage('')
    const form = new FormData(event.currentTarget)
    const email = String(form.get('email') || '').trim().toLowerCase()
    const password = String(form.get('password') || '')
    const displayName = String(form.get('displayName') || '').trim()
    let resultError: string | null = null
    try {
      if (mode === 'signin') {
        const result = await supabase.auth.signInWithPassword({ email, password })
        resultError = result.error?.message ?? null
      } else if (mode === 'signup') {
        const result = await supabase.auth.signUp({ email, password, options: { data: { display_name: displayName } } })
        resultError = result.error?.message ?? null
        if (!resultError && !result.data.session) setMessage('Account created. Check your email to confirm it, then return here to sign in. If you were invited to a workspace, use the same email address that received the invitation.')
        else if (!resultError) setMessage('Account created. Loading your workspace access…')
      } else if (mode === 'reset') {
        const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: window.location.origin })
        resultError = resetError?.message ?? null
        if (!resultError) setMessage('If an account exists for that email, a password-reset link will be sent. Open the link on this site to choose a new password.')
      } else {
        const { error: updateError } = await supabase.auth.updateUser({ password })
        resultError = updateError?.message ?? null
        if (!resultError) { setMessage('Password updated. You can continue with your account.'); setMode('signin'); await supabase.auth.signOut() }
      }
    } catch (cause) {
      resultError = cause instanceof Error ? cause.message : 'Authentication failed. Please try again.'
    } finally {
      setBusy(false)
    }
    if (resultError) setError(resultError)
    else if (mode === 'signin') setMessage('Signed in. Checking your workspace access…')
  }
  const title = mode === 'signin' ? 'Welcome back.' : mode === 'signup' ? 'Create your account.' : mode === 'reset' ? 'Reset your password.' : 'Choose a new password.'
  const description = mode === 'signin' ? 'One secure sign-in for your agency, team, and client access.' : mode === 'signup' ? 'Create one account to access workspaces you own or are invited to.' : mode === 'reset' ? 'Enter your account email and we will send a secure reset link if it exists.' : 'Set a new password for your Parallel Seven account.'
  return <div className="auth-screen"><form className="auth-card" onSubmit={submit}>
    <div className="auth-brand"><div className="auth-mark">P<span>7</span></div><div><b>PARALLEL SEVEN</b><small>AGENCY OPERATING SYSTEM</small></div></div>
    <div className="auth-eyebrow"><LockKeyhole size={14}/> ONE SECURE ACCOUNT · ALL WORKSPACES</div>
    <h1>{title}</h1><p>{description}</p>
    {mode === 'signup' && <label className="auth-field"><span>Your name</span><input name="displayName" autoComplete="name" required placeholder="Full name"/></label>}
    {mode !== 'update-password' && <label className="auth-field"><span>Email address</span><input name="email" type="email" autoComplete="email" required placeholder="you@company.com"/></label>}
    {mode !== 'reset' && <label className="auth-field"><span>{mode === 'update-password' ? 'New password' : 'Password'}</span><input name="password" type="password" autoComplete={mode === 'signin' ? 'current-password' : 'new-password'} minLength={8} required placeholder="At least 8 characters"/></label>}
    {error && <div className="auth-error" role="alert">{error}</div>}{message && <div className="auth-message" role="status">{message}</div>}
    <button className="auth-submit" disabled={busy}>{busy ? 'Please wait…' : mode === 'signin' ? 'Sign in' : mode === 'signup' ? 'Create account' : mode === 'reset' ? 'Send reset link' : 'Update password'} <ArrowRight size={16}/></button>
    {mode === 'signin' && <button className="auth-switch" type="button" onClick={() => { setMode('reset'); setError(''); setMessage('') }}>Forgot password?</button>}
    {mode !== 'update-password' && <button className="auth-switch" type="button" onClick={() => { setMode(mode === 'signup' ? 'signin' : 'signup'); setError(''); setMessage('') }}>{mode === 'signup' ? 'Already have an account? Sign in' : 'New to Parallel Seven? Create an account'}</button>}
    {mode === 'update-password' && <button className="auth-switch" type="button" onClick={() => { setMode('signin');  setError(''); setMessage('') }}>Back to sign in</button>}
    {mode === 'reset' && <button className="auth-switch" type="button" onClick={() => { setMode('signin'); setError(''); setMessage('') }}>Back to sign in</button>}
    <div className="auth-footnote">Use the same email for owner, staff, and client access. Your workspace memberships determine what you can see. New team members should accept an invitation using the invited email address.</div>
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
