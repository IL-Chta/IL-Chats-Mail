import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const json=(body:unknown,status=200)=>Response.json(body,{status});
const cleanAddress=(value="")=>{const match=String(value).match(/<([^>]+)>/);return (match?.[1]||String(value)).trim().toLowerCase()};
const safeName=(value="attachment")=>String(value).replace(/[^a-zA-Z0-9._-]/g,"_");
Deno.serve(async(req)=>{try{
  if(req.method!=="POST")return json({error:"Method not allowed"},405);
  const event=await req.json();
  if(event?.type!=="email.received")return json({ok:true});
  const url=Deno.env.get("SUPABASE_URL"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),key=Deno.env.get("RESEND_API_KEY");
  if(!url||!service||!key)return json({error:"Inbound service is not configured"},503);
  const admin=createClient(url,service),d=event.data||{},providerId=String(d.email_id||"");
  if(!providerId)return json({error:"Missing email id"},400);
  const recipients=(Array.isArray(d.to)?d.to:[d.to]).filter(Boolean).map(cleanAddress);
  const {data:profile}=await admin.from("profiles").select("id,email").in("email",recipients).limit(1).maybeSingle();
  if(!profile)return json({ok:true,ignored:true});
  const {data:existing}=await admin.from("messages").select("id").eq("external_message_id",providerId).maybeSingle();
  if(existing)return json({ok:true,duplicate:true,message_id:existing.id});
  const detailsResponse=await fetch("https://api.resend.com/emails/receiving/"+encodeURIComponent(providerId),{headers:{Authorization:"Bearer "+key}});
  const details=detailsResponse.ok?await detailsResponse.json():{};
  const messageId=crypto.randomUUID();
  const body=String(details.text||details.html||"");
  const {error:insertError}=await admin.from("messages").insert({id:messageId,thread_id:messageId,sender_id:null,recipient_id:profile.id,sender_email:cleanAddress(d.from||details.from||""),recipient_email:profile.email,to_emails:recipients,cc_emails:d.cc||[],bcc_emails:d.bcc||[],subject:d.subject||details.subject||"(sem assunto)",body,direction:"inbound",status:"received",sent_at:d.created_at||new Date().toISOString(),external_message_id:providerId});
  if(insertError)throw insertError;
  await admin.from("message_states").upsert({user_id:profile.id,message_id:messageId,folder:"inbox",is_read:false});
  const attachmentsResponse=await fetch("https://api.resend.com/emails/receiving/"+encodeURIComponent(providerId)+"/attachments",{headers:{Authorization:"Bearer "+key}});
  if(attachmentsResponse.ok){const payload=await attachmentsResponse.json();for(const a of payload.data||payload||[]){if(!a.download_url)continue;const response=await fetch(a.download_url);if(!response.ok)continue;const bytes=new Uint8Array(await response.arrayBuffer());const path=messageId+"/"+crypto.randomUUID()+"-"+safeName(a.filename);const {error:uploadError}=await admin.storage.from("mail-attachments").upload(path,bytes,{contentType:a.content_type||"application/octet-stream"});if(uploadError)continue;await admin.from("email_attachments").insert({message_id:messageId,owner_id:profile.id,storage_path:path,filename:a.filename||"attachment",content_type:a.content_type||"application/octet-stream",size_bytes:bytes.byteLength})}}
  return json({ok:true,message_id:messageId});
}catch(error){console.error(error);return json({ok:false,error:error?.message||"Internal error"},500)}});
