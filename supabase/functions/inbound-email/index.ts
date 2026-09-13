// IL Chats Mail v6 — esqueleto do webhook inbound. Validar assinatura do provedor antes de produção.
import { createClient } from 'npm:@supabase/supabase-js@2'
Deno.serve(async (req) => {
  if(req.method!=='POST') return new Response('Method not allowed',{status:405})
  // IMPORTANTE: antes de ativar em produção, implemente a verificação da assinatura do webhook Resend.
  const event=await req.json()
  if(event?.type!=='email.received') return Response.json({ok:true})
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const d=event.data||{}, recipient=(d.to||[])[0]||''
  const {data:profile}=await admin.from('profiles').select('id,email').eq('email',recipient).maybeSingle()
  if(!profile) return Response.json({ok:true,ignored:true})
  await admin.from('messages').insert({recipient_id:profile.id,sender_email:d.from||'',recipient_email:recipient,subject:d.subject||'(sem assunto)',body:'',direction:'inbound',provider:'resend',provider_message_id:d.email_id,delivery_status:'received'})
  return Response.json({ok:true})
})
