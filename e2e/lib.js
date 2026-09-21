const {initializeApp,cert}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getFirestore}=require('firebase-admin/firestore');
const crypto=require('crypto');
const KEY=process.env.GOOGLE_APPLICATION_CREDENTIALS;
if(!KEY){console.error('Set GOOGLE_APPLICATION_CREDENTIALS to the service-account JSON path (never commit it).');process.exit(2);}
initializeApp({credential:cert(require(require('path').resolve(KEY)))});
const a=getAuth(),db=getFirestore();
const URL=(process.env.BASE_URL||'https://local-job-connector-gh.web.app').replace(/[/]$/,'')+'/';
const made=[];
async function mkUser(tag,role,name){
  const pw=crypto.randomBytes(9).toString('base64url')+'#1a';
  const u=await a.createUser({email:`e2e.${tag}.${Date.now()}@example.com`,password:pw,emailVerified:true,displayName:name});
  await db.doc('users/'+u.uid).set({id:u.uid,displayName:name,phone:'0241234567',role,city:'Accra',rating:5,createdAt:new Date().toISOString()});
  made.push(u.uid);return {uid:u.uid,email:u.email,pw,name};
}
async function cleanup(){
  for(const uid of made){await db.doc('users/'+uid).delete().catch(()=>{});await a.deleteUser(uid).catch(()=>{});}
  for(const c of ['jobs','applications','chats']){
    const s=await db.collection(c).get();
    for(const d of s.docs){const x=d.data();
      if(JSON.stringify(x).includes('E2E')||made.some(m=>JSON.stringify(x).includes(m))){
        if(c==='chats'){const ms=await d.ref.collection('messages').get();for(const m of ms.docs)await m.ref.delete();}
        await d.ref.delete();}}}
}
const text=p=>p.evaluate(()=>document.body.innerText);
async function open(b,vp={width:1100,height:1000}){
  const p=await (await b.newContext({viewport:vp})).newPage();
  await p.goto(URL,{waitUntil:'networkidle'});await p.waitForTimeout(3000);
  await p.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await p.waitForTimeout(800);return p;
}
async function type(p,label,v){const l=p.locator('input[aria-label^="'+label+'"],textarea[aria-label^="'+label+'"]').first();await l.click({force:true});await p.waitForTimeout(450);await p.keyboard.press('Control+A');await p.keyboard.type(v,{delay:8});}
async function login(p,u){await type(p,'Email Address',u.email);await type(p,'Password',u.pw);await p.getByText('Sign In',{exact:true}).last().click();
  for(let i=0;i<25;i++){await p.waitForTimeout(1000);if(/Chats/.test(await text(p)))return true;}return false;}
module.exports={a,db,mkUser,cleanup,text,open,type,login,URL};
