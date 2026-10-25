'use strict';
// Legacy entry point; execution now requires the native Lua 5.1 gate.
const {spawnSync}=require('child_process');
const path=require('path');
const result=spawnSync('python3',[path.join(__dirname,'run_checks.py'),'--bootstrap'],{stdio:'inherit'});
if(result.error) throw result.error;
process.exit(result.status===null?1:result.status);
