import {initializeApp} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import {getAuth,signInWithEmailAndPassword,signOut,onAuthStateChanged} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import {getFirestore,collection,doc,getDoc,getDocs,onSnapshot,updateDoc,deleteDoc,query,orderBy,limit,writeBatch} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const app=initializeApp({apiKey:"AIzaSyAnrI4pr4q6Xa7kC9YtQn9phlYw4hY2Lxg",authDomain:"local-job-connector-gh.firebaseapp.com",projectId:"local-job-connector-gh",storageBucket:"local-job-connector-gh.firebasestorage.app",messagingSenderId:"212011996599",appId:"1:212011996599:web:36fb8496989886781cc432"});
const auth=getAuth(app),db=getFirestore(app);
const $=s=>document.querySelector(s);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const LIMIT=1000;
const data={users:[],jobs:[],applications:[],chats:[],reports:[]};
let unsubs=[],view="overview",filters={q:"",f:""};

const date=v=>{if(!v)return"";const d=v.toDate?v.toDate():new Date(v);return isNaN(d)?"":d.toLocaleString()};
const ts=v=>{if(!v)return 0;const d=v.toDate?v.toDate():new Date(v);return +d||0};
const toast=m=>{const t=$("#toast");t.textContent=m;t.classList.remove("hidden");setTimeout(()=>t.classList.add("hidden"),2500)};
const tag=s=>`<span class="tag t-${esc(s)}">${esc(s)}</span>`;

// ---------- auth ----------
$("#lf").onsubmit=async e=>{e.preventDefault();$("#le").textContent="";
  try{await signInWithEmailAndPassword(auth,$("#em").value.trim(),$("#pw").value)}
  catch(err){$("#le").textContent="Sign in failed: "+(err.code||err.message)}};
$("#out").onclick=()=>signOut(auth);
onAuthStateChanged(auth,async u=>{
  unsubs.forEach(f=>f());unsubs=[];
  if(!u){$("#app").classList.add("hidden");$("#login").classList.remove("hidden");return}
  let ok=false;
  try{ok=(await getDoc(doc(db,"admins",u.uid))).exists()}catch{}
  if(!ok){await signOut(auth);$("#le").textContent="This account is not an administrator.";return}
  $("#login").classList.add("hidden");$("#app").classList.remove("hidden");$("#me").textContent=u.email;
  start();
});

// ---------- data ----------
function start(){
  for(const c of Object.keys(data)){
    unsubs.push(onSnapshot(query(collection(db,c),limit(LIMIT)),
      s=>{data[c]=s.docs.map(d=>({...d.data(),id:d.id}));render()},
      e=>toast(`Cannot read ${c}: ${e.code}`)));
  }
  buildNav();
}
const pages={overview:"Overview",users:"Users",jobs:"Jobs",applications:"Applications",chats:"Chats",reports:"Reports"};
function buildNav(){
  $("#nav").innerHTML=Object.entries(pages).map(([k,v])=>`<button data-v="${k}" class="${k===view?"on":""}">${v}</button>`).join("");
  $("#nav").onclick=e=>{const v=e.target.dataset.v;if(v){view=v;filters={q:"",f:""};buildNav();render()}};
}
const match=(o,q)=>!q||Object.values(o).some(v=>typeof v!=="object"&&String(v).toLowerCase().includes(q));

async function act(fn,msg){try{await fn();toast(msg)}catch(e){toast("Failed: "+(e.code||e.message))}}
const ask=m=>confirm(m);

// ---------- views ----------
function render(){
  const m=$("#main");
  const q=filters.q.toLowerCase();
  if(view==="overview")return m.innerHTML=overview();
  const cfg=views[view];
  const rows=cfg.rows().filter(r=>match(r,q)&&(!filters.f||cfg.filter(r)===filters.f))
    .sort((a,b)=>ts(b[cfg.sort])-ts(a[cfg.sort]));
  const opts=cfg.opts?`<select id="f"><option value="">All</option>${cfg.opts.map(o=>`<option ${o===filters.f?"selected":""}>${o}</option>`).join("")}</select>`:"";
  const focused=document.activeElement&&document.activeElement.id==="q";
  m.innerHTML=`<div class="top"><h1>${pages[view]} <small style="color:var(--muted)">(${rows.length})</small></h1>${opts}
    <input id="q" placeholder="Search…" value="${esc(filters.q)}"><button class="btn" id="csv">Export CSV</button></div>
    <div class="tw">${rows.length?`<table><thead><tr>${cfg.cols.map(c=>`<th>${c[0]}</th>`).join("")}<th></th></tr></thead><tbody>${
      rows.map(r=>`<tr ${cfg.open?`class="click" data-open="${esc(r.id)}"`:""}>${cfg.cols.map(c=>`<td class="${c[2]||""}">${c[1](r)}</td>`).join("")}<td>${cfg.actions(r)}</td></tr>`).join("")}</tbody></table>`:`<div class="empty">Nothing here.</div>`}</div>`;
  const qi=$("#q");
  if(focused){qi.focus();qi.setSelectionRange(qi.value.length,qi.value.length)}
  qi.oninput=e=>{filters.q=e.target.value;render()};
  if($("#f"))$("#f").onchange=e=>{filters.f=e.target.value;render()};
  $("#csv").onclick=()=>csv(rows);
  m.onclick=e=>{
    const b=e.target.closest("button[data-a]");
    if(b){e.stopPropagation();cfg.handle(b.dataset.a,b.dataset.id,b);return}
    if(e.target.closest("select"))return;
    const tr=e.target.closest("[data-open]");if(tr&&cfg.open)cfg.open(tr.dataset.open);
  };
  m.onchange=e=>{const s=e.target.closest("select[data-a]");if(s)cfg.handle(s.dataset.a,s.dataset.id,s)};
}
function csv(rows){
  const keys=[...new Set(rows.flatMap(r=>Object.keys(r)))];
  const cell=v=>{let s=typeof v==="object"&&v!==null?JSON.stringify(v):String(v??"");
    if(/^[=+\-@]/.test(s))s="'"+s; // neutralise spreadsheet formula injection
    return `"${s.replace(/"/g,'""')}"`};
  const blob=new Blob([[keys.join(","),...rows.map(r=>keys.map(k=>cell(r[k])).join(","))].join("\n")],{type:"text/csv"});
  const a=document.createElement("a");a.href=URL.createObjectURL(blob);a.download=view+".csv";a.click();
}
const sel=(a,id,cur,opts)=>`<select data-a="${a}" data-id="${esc(id)}" style="width:auto;padding:4px 6px">${opts.map(o=>`<option ${o===cur?"selected":""}>${o}</option>`).join("")}</select>`;
const del=(a,id)=>`<button class="btn s d" data-a="${a}" data-id="${esc(id)}">Delete</button>`;

const views={
users:{rows:()=>data.users,sort:"createdAt",filter:r=>r.role,opts:["seeker","poster"],
  cols:[["Name",r=>esc(r.displayName)],["Phone",r=>esc(r.phone)],["Role",r=>tag(r.role)],["City",r=>esc(r.city)],["Rating",r=>esc(r.rating)],["Joined",r=>date(r.createdAt)]],
  actions:r=>sel("role",r.id,r.role,["seeker","poster"])+" "+del("del",r.id),
  handle(a,id,el){
    if(a==="role")act(()=>updateDoc(doc(db,"users",id),{role:el.value}),"Role updated");
    if(a==="del"&&ask("Delete this user profile? Their Firebase Auth account is not removed."))act(()=>deleteDoc(doc(db,"users",id)),"User deleted");}},
jobs:{rows:()=>data.jobs,sort:"createdAt",filter:r=>r.status||"open",opts:["open","inProgress","completed"],
  cols:[["Title",r=>esc(r.title),"w"],["Category",r=>esc(r.category)],["Pay",r=>`${esc(r.currency||"GHS")} ${esc(r.payRate)} ${esc(r.payUnit||"")}`],["City",r=>esc(r.city)],["Poster",r=>esc(r.posterName)],["Status",r=>tag(r.status||"open")],["Posted",r=>date(r.createdAt)]],
  actions:r=>sel("status",r.id,r.status||"open",["open","inProgress","completed"])+" "+del("del",r.id),
  handle(a,id,el){
    if(a==="status")act(()=>updateDoc(doc(db,"jobs",id),{status:el.value,isFilled:el.value!=="open"}),"Job updated");
    if(a==="del"&&ask("Delete this job?"))act(()=>deleteDoc(doc(db,"jobs",id)),"Job deleted");}},
applications:{rows:()=>data.applications,sort:"appliedAt",filter:r=>r.status,opts:["pending","accepted","rejected","completed"],
  cols:[["Job",r=>esc(r.jobTitle),"w"],["Applicant",r=>esc(r.seekerName)],["Phone",r=>esc(r.seekerPhone)],["Status",r=>tag(r.status)],["Note",r=>esc(r.note),"w"],["Applied",r=>date(r.appliedAt)]],
  actions:r=>sel("status",r.id,r.status,["pending","accepted","rejected","completed"])+" "+del("del",r.id),
  handle(a,id,el){
    if(a==="status")act(()=>updateDoc(doc(db,"applications",id),{status:el.value}),"Application updated");
    if(a==="del"&&ask("Delete this application?"))act(()=>deleteDoc(doc(db,"applications",id)),"Application deleted");}},
reports:{rows:()=>data.reports,sort:"createdAt",filter:r=>r.status,opts:["open","resolved","dismissed"],
  cols:[["Reported",r=>esc(r.targetTitle||r.targetId),"w"],["Type",r=>esc(r.targetType)],["Reason",r=>esc(r.reason),"w"],["Details",r=>esc(r.note),"w"],["Status",r=>tag(r.status)],["Filed",r=>date(r.createdAt)]],
  actions:r=>sel("status",r.id,r.status,["open","resolved","dismissed"])+" "+(r.targetType==="job"?`<button class="btn s d" data-a="rmjob" data-id="${esc(r.id)}">Remove job</button> `:"")+del("del",r.id),
  handle(a,id,el){
    const rep=data.reports.find(x=>x.id===id);
    if(a==="status")act(()=>updateDoc(doc(db,"reports",id),{status:el.value}),"Report updated");
    // The report's title is written by the reporter, so confirm against the real job.
    if(a==="rmjob"&&rep)act(async()=>{
      const ref=doc(db,"jobs",rep.targetId),j=await getDoc(ref);
      if(!j.exists())throw new Error("job no longer exists");
      if(!ask(`Delete "${j.data().title}" by ${j.data().posterName} and mark this report resolved?`))throw new Error("cancelled");
      await deleteDoc(ref);await updateDoc(doc(db,"reports",id),{status:"resolved"})},"Job removed, report resolved");
    if(a==="del"&&ask("Delete this report?"))act(()=>deleteDoc(doc(db,"reports",id)),"Report deleted");}},
chats:{rows:()=>data.chats,sort:"updatedAt",
  cols:[["Job",r=>esc(r.jobTitle),"w"],["Seeker",r=>esc(r.seekerName)],["Poster",r=>esc(r.posterName)],["Last message",r=>esc(r.lastMessage),"w"],["Updated",r=>date(r.updatedAt)]],
  actions:r=>`<button class="btn s" data-a="view" data-id="${esc(r.id)}">Open</button> `+del("del",r.id),
  open:id=>openChat(id),
  handle(a,id){
    if(a==="view")openChat(id);
    if(a==="del"&&ask("Delete this chat and all its messages?"))act(async()=>{
      const ms=await getDocs(collection(db,"chats",id,"messages"));
      const b=writeBatch(db);ms.docs.forEach(d=>b.delete(d.ref));b.delete(doc(db,"chats",id));await b.commit()},"Chat deleted");}}
};

function count(arr,f){const m={};arr.forEach(x=>{const k=f(x)||"—";m[k]=(m[k]||0)+1});return Object.entries(m).sort((a,b)=>b[1]-a[1])}
function bars(entries){const max=Math.max(1,...entries.map(e=>e[1]));return entries.slice(0,8).map(([k,v])=>`<div class="bar"><i title="${esc(k)}">${esc(k)}</i><div style="width:${v/max*100}%"></div><em>${v}</em></div>`).join("")||`<div class="empty">No data</div>`}
function overview(){
  const d=data,week=Date.now()-7*864e5;
  const open=d.jobs.filter(j=>(j.status||"open")==="open").length;
  const pend=d.applications.filter(a=>a.status==="pending").length;
  const avg=d.jobs.length?(d.jobs.reduce((s,j)=>s+(+j.payRate||0),0)/d.jobs.length).toFixed(2):"0";
  return `<div class="top"><h1>Overview</h1></div>
  <div class="grid">
   <div class="stat"><b>${d.users.length}</b><span>Users (${d.users.filter(u=>ts(u.createdAt)>week).length} new this week)</span></div>
   <div class="stat"><b>${d.jobs.length}</b><span>Jobs (${open} open)</span></div>
   <div class="stat"><b>${d.applications.length}</b><span>Applications (${pend} pending)</span></div>
   <div class="stat"><b>${d.chats.length}</b><span>Chat rooms</span></div>
   <div class="stat"><b>${d.reports.filter(r=>r.status==="open").length}</b><span>Open reports</span></div>
   <div class="stat"><b>${avg}</b><span>Avg. pay rate</span></div></div>
  <div class="cols">
   <div class="panel"><h3>Users by role</h3>${bars(count(d.users,u=>u.role))}</div>
   <div class="panel"><h3>Users by city</h3>${bars(count(d.users,u=>u.city))}</div>
   <div class="panel"><h3>Jobs by category</h3>${bars(count(d.jobs,j=>j.category))}</div>
   <div class="panel"><h3>Jobs by city</h3>${bars(count(d.jobs,j=>j.city))}</div>
   <div class="panel"><h3>Jobs by status</h3>${bars(count(d.jobs,j=>j.status||"open"))}</div>
   <div class="panel"><h3>Applications by status</h3>${bars(count(d.applications,a=>a.status))}</div>
  </div>
  ${[d.users,d.jobs,d.applications,d.chats,d.reports].some(a=>a.length>=LIMIT)?`<p style="color:var(--muted)">Showing the first ${LIMIT} documents per collection.</p>`:""}`;
}

// ---------- chat viewer ----------
function modal(html){$("#mb").innerHTML=html;$("#modal").classList.remove("hidden")}
$("#modal").onclick=e=>{if(e.target.id==="modal"||e.target.dataset.close!==undefined)$("#modal").classList.add("hidden")};
async function openChat(id){
  const c=data.chats.find(x=>x.id===id);if(!c)return;
  modal(`<h1>${esc(c.jobTitle)}</h1><p>${esc(c.seekerName)} ↔ ${esc(c.posterName)}</p><div class="msgs">Loading…</div><p><button class="btn" data-close>Close</button></p>`);
  try{
    const s=await getDocs(query(collection(db,"chats",id,"messages"),orderBy("timestamp"),limit(500)));
    const box=$("#mb .msgs");
    box.innerHTML=s.empty?`<div class="empty">No messages.</div>`:s.docs.map(d=>{const m=d.data();
      return `<div class="msg"><div><small>${esc(m.senderName)} · ${date(m.timestamp)}</small><br>${esc(m.text)}</div><button class="btn s d" data-m="${esc(d.id)}">Delete</button></div>`}).join("");
    box.onclick=async e=>{const mid=e.target.dataset.m;if(!mid||!ask("Delete this message?"))return;
      await act(()=>deleteDoc(doc(db,"chats",id,"messages",mid)),"Message deleted");e.target.closest(".msg").remove()};
  }catch(e){$("#mb .msgs").innerHTML=`<div class="empty">Failed: ${esc(e.code||e.message)}</div>`}
}
