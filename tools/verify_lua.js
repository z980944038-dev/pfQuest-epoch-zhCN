/* Parse game runtime Lua with Lua 5.1 grammar. Does not execute any addon. */
'use strict';
const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');
const root = path.resolve(__dirname, '..');
let total = 0;
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules') continue;
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (entry.name.endsWith('.lua')) {
      const contents = fs.readFileSync(file, 'utf8');
      try { luaparse.parse(contents, { luaVersion: '5.1' }); }
      catch (e) { throw new Error(`${path.relative(root,file)}: ${e.message}`); }
      total++;
    }
  }
}
walk(root);
if (total < 35) throw new Error(`Unexpected low Lua file count: ${total}`);
console.log(`PASS: parsed ${total} Lua files under Lua 5.1 grammar`);
