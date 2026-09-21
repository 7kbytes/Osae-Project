const {initializeApp,cert}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getFirestore}=require('firebase-admin/firestore');
const {chromium}=require('playwright');
const crypto=require('crypto');
const KEY=process.env.GOOGLE_APPLICATION_CREDENTIALS;
if(!KEY){console.error('Set GOOGLE_APPLICATION_CREDENTIALS');process.exit(2);}
initializeApp({credential:cert(require(require('path').resolve(KEY)))});
const URL=(process.env.BASE_URL||'https://local-job-connector-gh.web.app').replace(/[/]$/,'')+'/admin/';
const res=[];const ok=(n,c,d='')=>{res.push(c);console.log(c?'PASS':'FAIL',n,d)};
(async()=>{
 const a=getAuth(),db=getFirestore();const mk=async(em,admin)=>{const pw=crypto.randomBytes(9).toString('base64url')+'#1a';const u=await a.createUser({email:em,password:pw,emailVerified:true});if(admin)await db.doc('admins/'+u.uid).set({role:'admin',temp:true});return {u,pw}};
 const stamp=Date.now();
 const adm=await mk(`e2e.adm.${stamp}@example.com`,true), non=await mk(`e2e.non.${stamp}@example.com`,false);
 // seed one job + application so lists have data
 await db.doc('jobs/e2e_job').set({title:'E2E seeded job',description:'d',category:'Cleaning',payRate:50,payUnit:'per day',currency:'GHS',city:'Accra',posterId:'e2e_poster',posterName:'E2E',status:'open',createdAt:new Date().toISOString()});
 const b=await chromium.launch();
 try{
  const p=await (await b.newContext({viewport:{width:1300,height:900}})).newPage();
  p.on('pageerror',e=>console.log('PAGEERROR',e.message));
  await p.goto(URL,{waitUntil:'networkidle'});
  ok('admin login form visible',await p.locator('#lf').isVisible());
  await p.fill('#em',adm.u.email);await p.fill('#pw',adm.pw);await p.click('#lf button');
  await p.waitForSelector('#app:not(.hidden)',{timeout:15000}).catch(()=>{});
  ok('admin can sign in',await p.locator('#app').isVisible());
  await p.waitForTimeout(3500);await p.screenshot({path:'admin-overview.png'});
  const ov=await p.locator('#main').innerText();ok('overview shows stats',/Users/.test(ov)&&/Jobs/.test(ov),ov.replace(/\n/g,' ').slice(0,90));
  await p.click('#nav button[data-v="jobs"]');await p.waitForTimeout(1500);await p.screenshot({path:'admin-jobs.png'});
  ok('jobs list shows seeded job',(await p.locator('#main').innerText()).includes('E2E seeded job'));
  // change status via dropdown
  await p.locator('#main select[data-a="status"]').first().selectOption('inProgress');await p.waitForTimeout(2000);
  ok('admin can change job status',(await db.doc('jobs/e2e_job').get()).data().status==='inProgress');
  // delete job through UI
  p.once('dialog',d=>d.accept());await p.locator('#main button[data-a="del"]').first().click();await p.waitForTimeout(2000);
  ok('admin can delete job',!(await db.doc('jobs/e2e_job').get()).exists);
  await p.click('#nav button[data-v="users"]');await p.waitForTimeout(1500);await p.screenshot({path:'admin-users.png'});
  ok('users view loads',(await p.locator('#main').innerText()).length>20);
  for(const v of ['applications','chats']){await p.click(`#nav button[data-v="${v}"]`);await p.waitForTimeout(1200);
    const toast=await p.locator('#toast').isVisible()?await p.locator('#toast').innerText():'';ok(`${v} view loads without permission error`,!/Cannot read/.test(toast),toast);}
  // non-admin blocked
  const n=await (await b.newContext()).newPage();await n.goto(URL,{waitUntil:'networkidle'});
  await n.fill('#em',non.u.email);await n.fill('#pw',non.pw);await n.click('#lf button');await n.waitForTimeout(5000);
  ok('non-admin account is rejected',/not an administrator/.test(await n.locator('#le').innerText())&&!(await n.locator('#app').isVisible()));
 }finally{
  await b.close();
  for(const x of [adm,non]){await db.doc('admins/'+x.u.uid).delete().catch(()=>{});await db.doc('users/'+x.u.uid).delete().catch(()=>{});await a.deleteUser(x.u.uid).catch(()=>{});}
  await db.doc('jobs/e2e_job').delete().catch(()=>{});
  console.log('cleanup done');
 }
 console.log('SUMMARY',res.filter(Boolean).length,'passed',res.filter(x=>!x).length,'failed');
})().catch(e=>console.log('SCRIPT ERROR',e.message));
