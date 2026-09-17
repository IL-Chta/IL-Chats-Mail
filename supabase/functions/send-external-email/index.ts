import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"};
const json=(body,status=200)=>Response.json(body,{status,headers:cors});
Deno.serve(async(req)=>{try{
if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
if(req.method!=="POST")return json({error:"Method not allowed"},405);
const auth=req.headers.get("authorization")||"",url=Deno.env.get("SUPABASE_URL"),anon=Deno.env.get("SUPABASE_ANON_KEY"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),key=Deno.env.get("RESEND_API_KEY"),from=Deno.env.get("ILMAIL_FROM");
if(!auth)return json({error:"Unauthorized"},401); if(!url||!anon||!service||!key||!from)return json({error:"Email provider not configured"},503);
const userDb=createClient(url,anon,{global:{headers:{Authorization:auth}}}),admin=createClient(url,service),{data:{user}}=await userDb.auth.getUser(); if(!user)return json({error:"Unauthorized"},401);
const {message_id}=await req.json(); if(!message_id)return json({error:"message_id is required"},400);
const {data:m,error:me}=await userDb.from("messages").select("*").eq("id",message_id).eq("sender_id",user.id).single(); if(me||!m||m.status!=="draft")return json({error:"Invalid message"},403);
const {data:rows}=await userDb.from("email_attachments").select("storage_path,filename,content_type").eq("message_id",m.id); const attachments=[];
for(const a of rows||[]){const {data:file}=await userDb.storage.from("mail-attachments").download(a.storage_path);if(file){const bytes=new Uint8Array(await file.arrayBuffer());let bin="";for(let i=0;i<bytes.length;i+=32768)bin+=String.fromCharCode(...bytes.subarray(i,i+32768));attachments.push({filename:a.filename,content:btoa(bin),content_type:a.content_type})}}
const to=(m.to_emails?.length?m.to_emails:[m.recipient_email]).filter(Boolean); if(!to.length)return json({error:"Invalid recipient"},400);
console.log(JSON.stringify({stage:"resend_request",message_id:m.id})); const response=await fetch("https://api.resend.com/emails",{method:"POST",headers:{Authorization:"Bearer "+key,"content-type":"application/json"},body:JSON.stringify({from,to,cc:m.cc_emails||[],bcc:m.bcc_emails||[],subject:m.subject||"(sem assunto)",text:m.body||"",attachments})});
const result=await response.json().catch(()=>({message:"Invalid provider response"})); console.log(JSON.stringify({stage:"resend_response",message_id:m.id,status:response.status,provider_id:result?.id||null,error:result?.message||null}));
if(!response.ok){await admin.from("messages").update({status:"failed",failed_at:new Date().toISOString(),failure_reason:String(result?.message||"Provider error").slice(0,500)}).eq("id",m.id);return json({ok:false,provider_status:response.status,provider_response:result},response.status)}
await admin.from("messages").update({status:"sent",sent_at:new Date().toISOString(),external_message_id:result.id,failed_at:null,failure_reason:null}).eq("id",m.id); await admin.from("message_states").upsert({user_id:user.id,message_id:m.id,folder:"sent",is_read:true}); return json({ok:true,message_id:m.id,provider_status:response.status,provider_message_id:result.id});
}catch(e){console.error(e);return json({error:"Internal error"},500)}});
