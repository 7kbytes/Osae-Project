// Runs every end-to-end script; exits non-zero if any check fails.
const {spawnSync}=require('child_process');
const scripts=['auth.js','marketplace-flow.js','poster-flow.js','account.js','admin.js'];
let failed=0;
for(const s of scripts){
 console.log('\n=== '+s+' ===');
 const r=spawnSync('node',[s],{encoding:'utf8',env:process.env});
 const out=(r.stdout||'')+(r.stderr||'');process.stdout.write(out);
 if(r.status!==0||/^FAIL|SCRIPT ERROR/m.test(out))failed++;
}
spawnSync('node',['cleanup.js'],{stdio:'inherit',env:process.env});
console.log(failed?'\n'+failed+' script(s) FAILED':'\nAll e2e scripts passed');
process.exit(failed?1:0);
