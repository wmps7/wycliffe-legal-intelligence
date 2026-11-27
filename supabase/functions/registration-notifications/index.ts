// Server-side verified registration alerts. No registrant names, email addresses,
// identifiers or research content are transmitted to an email provider.
import { createClient } from "npm:@supabase/supabase-js@2";
const env = (k:string) => Deno.env.get(k) || "";
function equal(a:string,b:string) {
  const x=new TextEncoder().encode(a),y=new TextEncoder().encode(b);
  let diff=x.length^y.length;
  for(let i=0;i<Math.max(x.length,y.length);i++)diff|=(x[i]||0)^(y[i]||0);
  return diff===0;
}
Deno.serve(async(req)=>{
  const token=env("WLI_WORKER_TOKEN");
  if(req.method!=="POST"||!token||!equal(req.headers.get("x-wli-worker-token")||"",token))return new Response("Not authorised",{status:403});
  if(["SUPABASE_URL","SUPABASE_SERVICE_ROLE_KEY","RESEND_API_KEY","WLI_NOTIFICATION_FROM","WLI_NOTIFICATION_TO"].some(k=>!env(k)))return new Response("Delivery not configured",{status:503});
  if(new URL(req.url).searchParams.get("test")==="1"){
    const response=await fetch("https://api.resend.com/emails",{
      method:"POST",headers:{"Authorization":"Bearer "+env("RESEND_API_KEY"),"Content-Type":"application/json","Idempotency-Key":"wli-setup-test-20261127"},
      body:JSON.stringify({from:env("WLI_NOTIFICATION_FROM"),to:[env("WLI_NOTIFICATION_TO")],subject:"Wycliffe Legal Intelligence registration alerts test",text:"This is a setup test for your registration notification service. No personal information or real registration is included."})
    });
    return Response.json({test:true,accepted:response.ok,provider_status:response.status},{status:response.ok?200:502});
  }
  const db=createClient(env("SUPABASE_URL"),env("SUPABASE_SERVICE_ROLE_KEY"),{auth:{persistSession:false}});
  const {data,error}=await db.rpc("wli_claim_notification_ids");
  if(error)return new Response("Queue unavailable",{status:500});
  if(!data?.length)return Response.json({delivered:0});
  const ids=data.map((r:{user_id:string})=>r.user_id).sort();
  const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(ids.join(",")));
  const key=Array.from(new Uint8Array(digest)).map(b=>b.toString(16).padStart(2,"0")).join("");
  const response=await fetch("https://api.resend.com/emails",{
    method:"POST",headers:{"Authorization":"Bearer "+env("RESEND_API_KEY"),"Content-Type":"application/json","Idempotency-Key":"wli-batch-"+key},
    body:JSON.stringify({from:env("WLI_NOTIFICATION_FROM"),to:[env("WLI_NOTIFICATION_TO")],subject:"New verified WLI registrations",text:data.length+" new verified registration(s). Sign in to your private Supabase Authentication dashboard to review user details."})
  });
  if(!response.ok)return new Response("Mail delivery failed",{status:502});
  let delivered=0;
  for(const id of ids){const {error}=await db.rpc("wli_mark_notification_delivered",{p_user_id:id});if(!error)delivered++}
  return Response.json({delivered});
});
