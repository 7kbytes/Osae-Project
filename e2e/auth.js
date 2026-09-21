const {chromium}=require('playwright');
const URL=(process.env.BASE_URL||'https://local-job-connector-gh.web.app').replace(/[/]$/,'');
const stamp=Date.now();
const EMAIL=`e2e.test.${stamp}@example.com`, PW='E2eTest#'+stamp;
const results=[];const ok=(n,c,d='')=>{results.push([c?'PASS':'FAIL',n,d]);console.log(c?'PASS':'FAIL',n,d)};
async function openApp(b){
 const ctx=await b.newContext({viewport:{width:1100,height:1000}});const p=await ctx.newPage();
 await p.goto(URL+'/',{waitUntil:'networkidle'});await p.waitForTimeout(3000);
 await p.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await p.waitForTimeout(1000);
 return p;
}
async function fillF(p,label,val){const l=p.locator('input[aria-label^="'+label+'"],textarea[aria-label^="'+label+'"]').first();await l.click({force:true});await p.waitForTimeout(450);await p.keyboard.press('Control+A');await p.keyboard.type(val,{delay:15});}
const btn=(p,name)=>p.getByText(name,{exact:true}).last();
const text=p=>p.evaluate(()=>document.body.innerText);
(async()=>{
 const b=await chromium.launch();
 // 1. wrong credentials rejected
 let p=await openApp(b);
 ok('starts on login screen',/Sign in to access/.test(await text(p)));
 await fillF(p,'Email Address','nobody@example.com');
 await fillF(p,'Password','wrong-password-1');
 await btn(p,'Sign In').click();await p.waitForTimeout(4000);
 let t=await text(p);
 ok('wrong credentials rejected with message',/Incorrect email or password/.test(t)&&!/Post Gig/.test(t),t.includes('Incorrect')?'':t.slice(0,120));
 await p.screenshot({path:'e2e-wrong.png'});
 // 2. sign up as employer (fresh page so no stale field text)
 await p.context().close();p=await openApp(b);
 await p.getByText('Register Now').click();await p.waitForTimeout(800);
 await fillF(p,'Full Name','E2E Test Poster');
 await fillF(p,'Phone Number','0241234567');
 await fillF(p,'Email Address',EMAIL);
 await fillF(p,'Password',PW);
 await p.getByText(/Job Seeker/).first().click();await p.waitForTimeout(600);await p.screenshot({path:'e2e-menu.png'});await p.mouse.click(65,628);await p.waitForTimeout(500);
 await btn(p,'Create Account').click();for(let i=0;i<30;i++){await p.waitForTimeout(1000);if(/Chats/.test(await text(p)))break;}
 t=await text(p);await p.screenshot({path:'e2e-signedin.png'});
 ok('sign-up lands in main app',/Post Gig|Jobs/.test(t)&&/Chats/.test(t),t.slice(0,100).replace(/\n/g,' | '));
 ok('no mock jobs shown',!/Emmanuel Duodu Osae/.test(t));
 // 3. session persists after reload
 await p.reload({waitUntil:'load'});await p.waitForTimeout(3500);
 await p.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await p.waitForTimeout(800);
 t=await text(p);ok('session persists after reload',/Chats/.test(t)&&!/Sign in to access/.test(t));
 // 4. sign out then wrong password for real account
 await p.getByText('Profile').click();await p.waitForTimeout(1500);
 await p.screenshot({path:'e2e-profile.png'});
 t=await text(p);ok('profile shows real email',t.includes(EMAIL),t.includes(EMAIL)?'':t.slice(0,150).replace(/\n/g,' | '));
 const so=p.getByText(/Sign Out|Log Out|Logout/i);
 if(await so.count()){await so.first().click();await p.waitForTimeout(2000);
   const c=p.getByRole('button',{name:/Sign Out|Log Out|Logout|Confirm/i});if(await c.count()>1)await c.last().click();await p.waitForTimeout(2500);}
 t=await text(p);ok('sign out returns to login',/Sign in to access/.test(t));
 if(/Sign in to access/.test(t)){
  await fillF(p,'Email Address',EMAIL);await fillF(p,'Password','WrongPass#1');
  await btn(p,'Sign In').click();await p.waitForTimeout(3500);
  ok('real account + wrong password rejected',/Incorrect email or password/.test(await text(p)));
  await fillF(p,'Password',PW);await btn(p,'Sign In').click();await p.waitForTimeout(5000);
  ok('real account + right password signs in',/Chats/.test(await text(p)));
 }
 console.log('TESTEMAIL',EMAIL);
 // 5. admin dashboard
 if(!process.env.ADMINPW){console.log('ADMIN SECTION SKIPPED');await b.close();console.log('SUMMARY',results.filter(r=>r[0]==='PASS').length,'passed',results.filter(r=>r[0]==='FAIL').length,'failed');return;}
 const ctx=await b.newContext({viewport:{width:1300,height:900}});const a=await ctx.newPage();
 a.on('pageerror',e=>console.log('ADMIN PAGEERROR',e.message));
 await a.goto(URL+'/admin/',{waitUntil:'networkidle'});
 ok('admin login form visible',await a.locator('#lf').isVisible());
 await a.fill('#em','admin@local-job-connector.app');await a.fill('#pw',process.env.ADMINPW);
 await a.click('#lf button');await a.waitForSelector('#app:not(.hidden)',{timeout:15000}).catch(()=>{});
 ok('admin signs in',await a.locator('#app').isVisible());
 await a.waitForTimeout(3000);await a.screenshot({path:'admin-overview.png'});
 let ov=await a.locator('#main').innerText();ok('overview renders stats',/Users/.test(ov)&&/Jobs/.test(ov),ov.replace(/\n/g,' ').slice(0,120));
 await a.click('#nav button[data-v="users"]');await a.waitForTimeout(1500);await a.screenshot({path:'admin-users.png'});
 const ut=await a.locator('#main').innerText();ok('admin sees the new test user',ut.includes('E2E Test Poster'));
 for(const v of ['jobs','applications','chats']){await a.click(`#nav button[data-v="${v}"]`);await a.waitForTimeout(1200);
   const e=await a.locator('#main').innerText();ok(`admin ${v} view loads (no permission error)`,!/Cannot read/.test(await a.locator('#toast').innerText().catch(()=>''))&&e.length>0);}
 // non-admin cannot use dashboard
 const ctx2=await b.newContext();const n=await ctx2.newPage();await n.goto(URL+'/admin/',{waitUntil:'networkidle'});
 await n.fill('#em',EMAIL);await n.fill('#pw',PW);await n.click('#lf button');await n.waitForTimeout(5000);
 ok('non-admin rejected by dashboard',/not an administrator/.test(await n.locator('#le').innerText())&&!(await n.locator('#app').isVisible()));
 await b.close();
 console.log('\nSUMMARY',results.filter(r=>r[0]==='PASS').length,'passed',results.filter(r=>r[0]==='FAIL').length,'failed');
})().catch(e=>{console.log('SCRIPT ERROR',e.message);process.exit(1)});
