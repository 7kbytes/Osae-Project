const {chromium}=require('playwright');const L=require('./lib');
const res=[];const ok=(n,c,d='')=>{res.push(c);console.log(c?'PASS':'FAIL',n,d)};
(async()=>{
 const poster=await L.mkUser('poster','poster','E2E Poster'),seeker=await L.mkUser('seeker','seeker','E2E Seeker');
 const b=await chromium.launch();
 try{
  // ---- poster posts a job
  const pp=await L.open(b);ok('poster signs in',await L.login(pp,poster));
  await pp.getByText('Post Gig').click();await pp.waitForTimeout(1500);
  await L.type(pp,'Job Title','E2E Garden cleanup');await L.type(pp,'Pay Amount (GHS)','120');
  await L.type(pp,'Exact Location / Landmark','Osu Oxford Street');
  await L.type(pp,'Job Description','Clear leaves and trim hedges. Bring own tools.');
  await pp.screenshot({path:'flow-filled.png'});await pp.getByText('Publish Job Posting').click();
  let job=null;for(let i=0;i<15&&!job;i++){await pp.waitForTimeout(1000);const s=await L.db.collection('jobs').where('posterId','==',poster.uid).get();if(!s.empty)job={id:s.docs[0].id,...s.docs[0].data()};}
  await pp.screenshot({path:'flow-posted.png'});
  ok('job saved to Firestore with poster id',!!job&&job.title==='E2E Garden cleanup'&&job.payRate===120,job?JSON.stringify({s:job.status,c:job.city,pay:job.payRate}):'not found');
  // ---- seeker finds job and applies
  const sp=await L.open(b);ok('seeker signs in',await L.login(sp,seeker));
  await sp.waitForTimeout(6000);let t=await L.text(sp);
  await sp.screenshot({path:'flow-feed.png'});
  await sp.mouse.click(1019,371);await sp.waitForTimeout(2000);await sp.screenshot({path:'flow-detail.png'});
  t=await L.text(sp);console.log('DETAIL:',t.replace(/\n/g,' | ').slice(0,300));
  const applyBtn=sp.getByText(/Apply/i).last();
  ok('job detail shows Apply action',await applyBtn.count()>0);
  await applyBtn.click();await sp.waitForTimeout(1500);await sp.screenshot({path:'flow-apply.png'});
  await sp.getByText('Submit Application').last().click();
  let app=null;for(let i=0;i<15&&!app;i++){await sp.waitForTimeout(1000);const q=await L.db.collection('applications').where('seekerId','==',seeker.uid).get();if(!q.empty)app={id:q.docs[0].id,...q.docs[0].data()};}
  ok('application saved with correct seeker/poster/status',!!app&&app.posterId===poster.uid&&app.status==='pending'&&app.jobId===job.id,app?JSON.stringify({st:app.status,poster:app.posterId===poster.uid}):'not found');
  await sp.screenshot({path:'flow-applied.png'});
  console.log('AFTER APPLY:',(await L.text(sp)).split(String.fromCharCode(10)).join(' | ').slice(0,250));
  // seeker starts a chat
  const chatBtn=sp.getByText('Start Chat with Employer');
  if(await chatBtn.count()){await chatBtn.click();await sp.waitForTimeout(3000);await sp.screenshot({path:'flow-chat.png'});console.log('CHAT SCREEN:',(await L.text(sp)).split(String.fromCharCode(10)).join(' | ').slice(0,300));
    console.log(await sp.evaluate(()=>[...document.querySelectorAll('input,textarea')].map(e=>e.tagName+':'+e.getAttribute('aria-label')).join(',')));}
  const chats=await L.db.collection('chats').where('seekerId','==',seeker.uid).get();
  ok('chat room created in Firestore for seeker+poster',chats.size===1&&chats.docs[0].data().posterId===poster.uid,'rooms='+chats.size+(chats.size?' id='+chats.docs[0].id:''));
 }catch(e){console.log('SCRIPT ERROR',e.message)}
 finally{await b.close();
  const apps=await L.db.collection('applications').where('seekerId','==',seeker.uid).get();console.log('applications by seeker:',apps.size,apps.docs.map(d=>d.data().status));
  await L.cleanup();console.log('cleanup done');}
 console.log('SUMMARY',res.filter(Boolean).length,'passed',res.filter(x=>!x).length,'failed');
})();
