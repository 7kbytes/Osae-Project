// Forgot-password and self-service account deletion against the deployed app.
const {chromium}=require('playwright');const L=require('./lib');
const res=[];const ok=(n,c,d='')=>{res.push(c);console.log(c?'PASS':'FAIL',n,d)};
(async()=>{
 const u=await L.mkUser('acct','poster','E2E Account');
 const b=await chromium.launch();
 try{
  // forgot password (signed out)
  let p=await L.open(b);
  await L.type(p,'Email Address',u.email);
  await p.getByText('Forgot password?').click();await p.waitForTimeout(2500);
  ok('forgot password confirms without revealing account existence',/reset link has been sent/.test(await L.text(p)));
  // invalid email is rejected (fresh page so the field is empty)
  p=await L.open(b);
  await L.type(p,'Email Address','not-an-email');
  await p.getByText('Forgot password?').click();await p.waitForTimeout(1500);
  ok('forgot password rejects a malformed email',/valid email/.test(await L.text(p)));
  // delete account
  p=await L.open(b);ok('signs in',await L.login(p,u));
  await p.getByText('Profile').first().click();await p.waitForTimeout(2000);
  await p.getByText('Delete My Account').click();await p.waitForTimeout(1000);
  await p.getByText('Delete',{exact:true}).last().click();
  let gone=false;for(let i=0;i<20&&!gone;i++){await p.waitForTimeout(1000);try{await L.a.getUser(u.uid);}catch{gone=true;}}
  ok('login is removed from Firebase Auth',gone);
  ok('profile document is removed',!(await L.db.doc('users/'+u.uid).get()).exists);
  await p.waitForTimeout(2000);
  ok('app returns to the login screen',/Sign in to access/.test(await L.text(p)));
 }catch(e){console.log('SCRIPT ERROR',e.message);res.push(false)}
 finally{await b.close();await L.cleanup();}
 console.log('SUMMARY',res.filter(Boolean).length,'passed',res.filter(x=>!x).length,'failed');
 process.exit(res.some(x=>!x)?1:0);
})();
