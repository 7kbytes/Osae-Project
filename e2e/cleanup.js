// Removes leftover e2e.* test accounts (created by auth.js through the UI).
const {a,db}=require('./lib');
(async()=>{
 const {users}=await a.listUsers(1000);
 const test=users.filter(u=>/^e2e\.[a-z]+\.\d+@example\.com$/.test(u.email||''));
 for(const u of test){await db.doc('users/'+u.uid).delete().catch(()=>{});await a.deleteUser(u.uid).catch(()=>{});}
 console.log('removed',test.length,'e2e accounts');
})();
