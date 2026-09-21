const {chromium}=require('playwright');const L=require('./lib');
const flat=t=>t.split(String.fromCharCode(10)).join(' | ');
(async()=>{
 const poster=await L.mkUser('poster','poster','E2E Poster'),seeker=await L.mkUser('seeker','seeker','E2E Seeker');
 const now=new Date().toISOString();
 await L.db.doc('jobs/e2e_job').set({id:'e2e_job',title:'E2E Roof repair',description:'d',category:'Construction & Labor',payRate:200,payUnit:'per day',currency:'GHS',city:'Accra',locationName:'Osu',latitude:5.5,longitude:-0.2,posterId:poster.uid,posterName:'E2E Poster',posterPhone:'0241234567',status:'open',isFilled:false,createdAt:now});
 await L.db.doc('applications/e2e_app').set({id:'e2e_app',jobId:'e2e_job',jobTitle:'E2E Roof repair',seekerId:seeker.uid,seekerName:'E2E Seeker',seekerPhone:'0241112222',posterId:poster.uid,status:'pending',note:'E2E note',appliedAt:now});
 const cid='chat_e2e_job_'+seeker.uid;
 await L.db.doc('chats/'+cid).set({id:cid,jobId:'e2e_job',jobTitle:'E2E Roof repair',seekerId:seeker.uid,seekerName:'E2E Seeker',posterId:poster.uid,posterName:'E2E Poster',lastMessage:'E2E hello from seeker',updatedAt:now});
 await L.db.doc('chats/'+cid+'/messages/m1').set({id:'m1',senderId:seeker.uid,senderName:'E2E Seeker',text:'E2E hello from seeker',timestamp:now,isRead:false});
 const b=await chromium.launch();
 try{
  const p=await L.open(b);console.log('poster login',await L.login(p,poster));
  await p.getByText('Chats').first().click();await p.waitForTimeout(4000);await p.screenshot({path:'p-chats.png'});
  console.log('CHATS:',flat(await L.text(p)).slice(0,300));
  const ct=flat(await L.text(p));
  console.log(ct.includes('E2E Seeker')?'PASS chat list shows the seeker (other party) to the poster':'FAIL chat list does not show seeker name');
  // open the room and reply
  await p.mouse.click(300,110);await p.waitForTimeout(3000);await p.screenshot({path:'p-room.png'});
  console.log('ROOM:',flat(await L.text(p)).slice(0,200));
  await L.type(p,'Type your message','E2E reply from poster');await p.keyboard.press('Enter');await p.waitForTimeout(3000);
  const ms=await L.db.collection('chats/'+cid+'/messages').get();
  const rep=ms.docs.map(d=>d.data()).find(m=>m.text==='E2E reply from poster');
  console.log(rep&&rep.senderId===poster.uid?'PASS poster reply saved with own senderId':'FAIL reply not saved (msgs='+ms.size+')');
  await p.screenshot({path:'p-room2.png'});
  // back, then open own job -> view applicants
  await p.getByText('Back').first().click();await p.waitForTimeout(1000);
  await p.getByText('Jobs').first().click();await p.waitForTimeout(5000);await p.screenshot({path:'p-feed.png'});
  await p.mouse.click(1019,371);await p.waitForTimeout(2500);await p.screenshot({path:'p-detail.png'});
  console.log('P DETAIL:',flat(await L.text(p)).slice(0,300));
  const va=p.getByText(/View Applicants/);
  console.log((await va.count())?'PASS poster sees View Applicants on own job':'FAIL no View Applicants button');
  if(await va.count()){await va.first().click();await p.waitForTimeout(3000);await p.screenshot({path:'p-applicants.png'});
    console.log('APPLICANTS:',flat(await L.text(p)).slice(0,300));
    const acc=p.getByText(/^Accept/);if(await acc.count()){await acc.first().click();await p.waitForTimeout(3000);
      const a=(await L.db.doc('applications/e2e_app').get()).data();console.log(a.status==='accepted'?'PASS poster accepted the application (Firestore=accepted)':'FAIL status='+a.status);}
    else console.log('no Accept control found');}
 }finally{await b.close();await L.cleanup();}
})().catch(e=>console.log('ERR',e.message));
