import { useEffect, useState } from 'react'
import { ActivityIndicator, Image, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = process.env.EXPO_PUBLIC_SUPABASE_URL
const key = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY
const client: SupabaseClient | null = url && key ? createClient(url, key) : null
const lime = '#FF3217'

export default function HomeScreen() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [displayName, setDisplayName] = useState('')
  const [userEmail, setUserEmail] = useState<string | null>(null)
  const [loading, setLoading] = useState(Boolean(client))
  const [busy, setBusy] = useState(false)
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  useEffect(() => {
    if (!client) return
    client.auth.getSession().then(({ data }) => { setUserEmail(data.session?.user.email ?? null); setLoading(false) })
    const { data } = client.auth.onAuthStateChange((_event, session) => setUserEmail(session?.user.email ?? null))
    return () => data.subscription.unsubscribe()
  }, [])
  async function authenticate() {
    if (!client) return
    setBusy(true); setError(''); setMessage('')
    const result = mode === 'signin'
      ? await client.auth.signInWithPassword({ email: email.trim(), password })
      : await client.auth.signUp({ email: email.trim(), password, options: { data: { display_name: displayName.trim() } } })
    setBusy(false)
    if (result.error) setError(result.error.message)
    else if (mode === 'signup' && !result.data.session) setMessage('Check your email to confirm your account, then sign in.')
    else setMessage('Authenticated. Workspace membership and cloud-backed records are the next integration step.')
  }
  return <SafeAreaView style={s.safe}><ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
    <View style={s.brandRow}><Image source={require('../assets/parallel-seven-logo.jpg')} resizeMode="contain" style={s.brandImage}/></View>
    <Text style={s.eyebrow}>BEYOND THE UNEXPECTED</Text><Text style={s.title}>Your studio.{ '\n' }In sync.</Text><Text style={s.subtitle}>A connected workspace for client relationships, creative projects, and delivery.</Text>
    {loading ? <View style={s.card}><ActivityIndicator color={lime}/></View> : userEmail ? <View style={s.card}><Text style={s.cardLabel}>AUTHENTICATED SESSION</Text><Text style={s.cardValue}>{userEmail}</Text><Text style={s.cardHint}>This mobile foundation is connected to Supabase Auth. Organization switching and cloud records are being wired into the shared backend.</Text><Pressable style={s.primary} onPress={() => client?.auth.signOut()}><Text style={s.primaryText}>Sign out</Text></Pressable></View> : !client ? <View style={s.card}><Text style={s.cardLabel}>PREVIEW MODE</Text><Text style={s.cardValue}>Supabase is not configured</Text><Text style={s.cardHint}>Add EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY to mobile/.env to enable authentication.</Text></View> : <View style={s.card}>
      <Text style={s.cardLabel}>SECURE WORKSPACE ACCESS</Text><Text style={s.formTitle}>{mode === 'signin' ? 'Welcome back.' : 'Create your account.'}</Text>
      {mode === 'signup' && <TextInput value={displayName} onChangeText={setDisplayName} placeholder="Full name" placeholderTextColor="#777B8A" autoCapitalize="words" style={s.input}/>}
      <TextInput value={email} onChangeText={setEmail} placeholder="Email address" placeholderTextColor="#777B8A" autoCapitalize="none" keyboardType="email-address" autoComplete="email" style={s.input}/>
      <TextInput value={password} onChangeText={setPassword} placeholder="Password (8+ characters)" placeholderTextColor="#777B8A" secureTextEntry autoComplete={mode === 'signin' ? 'current-password' : 'new-password'} style={s.input}/>
      {!!error && <Text style={s.error}>{error}</Text>}{!!message && <Text style={s.message}>{message}</Text>}
      <Pressable style={s.primary} disabled={busy || !email.trim() || password.length < 8} onPress={authenticate}><Text style={s.primaryText}>{busy ? 'Please wait…' : mode === 'signin' ? 'Sign in' : 'Create account'}</Text></Pressable>
      <Pressable onPress={() => { setMode(mode === 'signin' ? 'signup' : 'signin'); setError(''); setMessage('') }}><Text style={s.switch}>{mode === 'signin' ? 'Create an account' : 'Already registered? Sign in'}</Text></Pressable>
    </View>}
    <View style={s.metrics}><Metric label="Projects" value="--"/><Metric label="Open tasks" value="--"/><Metric label="Approvals" value="--"/></View>
    <View style={s.note}><Text style={s.noteTitle}>Built for multi-division teams</Text><Text style={s.noteText}>Creative · Media · Studios · Labs</Text></View>
  </ScrollView></SafeAreaView>
}
function Metric({label,value}:{label:string;value:string}) { return <View style={s.metric}><Text style={s.metricValue}>{value}</Text><Text style={s.metricLabel}>{label}</Text></View> }
const s = StyleSheet.create({ safe:{flex:1,backgroundColor:'#08090B'},content:{padding:24,paddingTop:34,gap:22},brandRow:{flexDirection:'row',alignItems:'center',gap:12},brandImage:{width:245,height:78,maxWidth:'100%'},eyebrow:{fontSize:10,letterSpacing:2,color:lime,marginTop:22},title:{fontSize:42,fontWeight:'800',letterSpacing:-1.5,color:'#F3F4F7',lineHeight:46},subtitle:{fontSize:14,lineHeight:22,color:'#A2A6B5',maxWidth:330},card:{padding:18,borderRadius:16,borderWidth:1,borderColor:'#30333E',backgroundColor:'#191C25',gap:12},cardLabel:{fontSize:10,letterSpacing:1.5,color:'#898D9C'},cardValue:{fontSize:15,fontWeight:'700',color:'#F0F1F5'},cardHint:{fontSize:12,lineHeight:19,color:'#979BAA'},formTitle:{fontSize:24,fontWeight:'800',color:'#F0F1F5',marginVertical:3},input:{borderWidth:1,borderColor:'#373B47',borderRadius:8,padding:12,color:'#F0F1F5',fontSize:13,backgroundColor:'#13151D'},primary:{alignItems:'center',justifyContent:'center',padding:13,borderRadius:8,backgroundColor:lime,marginTop:2},primaryText:{fontSize:12,fontWeight:'800',color:'#FFFFFF'},switch:{textAlign:'center',fontSize:11,color:lime,padding:7},error:{fontSize:11,color:'#FFB2B2'},message:{fontSize:11,color:'#FF9A88'},metrics:{flexDirection:'row',gap:9},metric:{flex:1,padding:13,borderRadius:12,backgroundColor:'#191C25',borderWidth:1,borderColor:'#2A2D38'},metricValue:{fontSize:22,fontWeight:'800',color:lime},metricLabel:{fontSize:10,color:'#969AAA',marginTop:5},note:{padding:16,borderRadius:12,backgroundColor:'#241411',borderWidth:1,borderColor:'#4A241E'},noteTitle:{fontSize:13,fontWeight:'700',color:'#FFE3DE'},noteText:{fontSize:12,color:'#D7A49B',marginTop:6}})
