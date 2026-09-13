// IL Chats Mail v6 — envio externo via Resend. RESEND_API_KEY e ILMAIL_FROM devem ser Secrets do Supabase.
import { createClient } from 'npm:@supabase/supabase-js@2'
Deno.serve(async (req) => {
  try {
    const auth = req.headers.get('Authorization') || ''
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {global:{headers:{Authorization:auth}}})
    const {data:{user}} = await sb.auth.getUser()
    if (!user) return new Response('Unauthorized',{status:401})
    const {to,subject,body} = await req.json()
    if (!to || !/^\S+@\S+\.\S+$/.test(to)) return new Response('Invalid recipient',{status:400})
    const key=Deno.env.get('RESEND_API_KEY'), from=Deno.env.get('ILMAIL_FROM')
    if(!key||!from) return new Response('Email provider not configured',{status:503})
    const rr=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify({from,to:[to],subject:subject||'(sem assunto)',text:body||''})})
    const result=await rr.json(); if(!rr.ok) return Response.json(result,{status:rr.status})
    const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    await admin.from('messages').insert({sender_id:user.id,sender_email:user.email,recipient_email:to,subject:subject||'(sem assunto)',body:body||'',direction:'outbound',provider:'resend',provider_message_id:result.id,delivery_status:'sent'})
    return Response.json({ok:true,id:result.id})
  } catch(e){return Response.json({error:String(e)},{status:500})}
})
