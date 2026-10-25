#!/usr/bin/env python3
"""Native Lua 5.1 verification gate. Python 3.12+; no API keys or game account needed."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from verify_translation import verify, require

ROOT=Path(__file__).resolve().parent.parent
LUA_SHA='2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333'
BASE_SHA='b81ef4dd3b19fc8893da525e91d7dd6869a180cc2b9bf0943f769c1ad0bfb34c'

def fetch_pinned(url: str,path: Path,expected: str) -> None:
    if not path.exists():
        request=urllib.request.Request(url,headers={'User-Agent':'pfQuest-epoch-zhCN-QA/3'})
        with urllib.request.urlopen(request,timeout=45) as response:
            blob=response.read()
        require(hashlib.sha256(blob).hexdigest()==expected,'Downloaded dependency hash mismatch: '+path.name)
        path.write_bytes(blob)
    require(hashlib.sha256(path.read_bytes()).hexdigest()==expected,'Cached dependency hash mismatch: '+path.name)

def bootstrap(directory: Path) -> tuple[Path,Path,Path]:
    directory.mkdir(parents=True,exist_ok=True)
    lua_archive=directory/'lua-5.1.5.tar.gz'
    fetch_pinned('https://www.lua.org/ftp/lua-5.1.5.tar.gz',lua_archive,LUA_SHA)
    source=directory/'lua-5.1.5'
    if not source.exists():
        with tarfile.open(lua_archive) as archive:
            archive.extractall(directory,filter='data')
    lua,luac=source/'src/lua',source/'src/luac'
    if not lua.is_file() or not luac.is_file():
        built=subprocess.run(['make','generic'],cwd=source,capture_output=True,text=True,timeout=180)
        (directory/'lua-build.log').write_text(built.stdout+built.stderr,encoding='utf-8')
        require(built.returncode==0,'Lua build failed; see .qa-deps/lua-build.log')
    base_archive=directory/'pfQuest-enUS-wotlk-7.0.1.zip'
    fetch_pinned('https://github.com/shagu/pfQuest/releases/download/7.0.1/pfQuest-enUS-wotlk.zip',base_archive,BASE_SHA)
    base=directory/'pfQuest-wotlk'
    if not base.exists():
        with zipfile.ZipFile(base_archive) as archive:
            for entry in archive.infolist():
                path=Path(entry.filename)
                require(not path.is_absolute() and '..' not in path.parts and not stat.S_ISLNK(entry.external_attr>>16),'Unsafe dependency archive member')
            require(archive.testzip() is None,'Dependency archive CRC error')
            archive.extractall(directory)
    return lua.resolve(),luac.resolve(),base.resolve()

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bootstrap',action='store_true',help='Download and build SHA256-pinned Lua 5.1 and the original base addon into .qa-deps')
    parser.add_argument('--lua',type=Path)
    parser.add_argument('--luac',type=Path)
    parser.add_argument('--base-dir',type=Path)
    parser.add_argument('--output',type=Path,default=ROOT/'.qa-results/RESULT.json')
    args=parser.parse_args()
    if args.bootstrap:
        lua,luac,base=bootstrap(ROOT/'.qa-deps')
    else:
        require(all([args.lua,args.luac,args.base_dir]),'Pass --bootstrap or all of --lua, --luac and --base-dir')
        lua,luac,base=args.lua.resolve(),args.luac.resolve(),args.base_dir.resolve()
    require(lua.is_file() and luac.is_file() and base.is_dir(),'Missing local native QA dependencies')
    version=subprocess.run([str(lua),'-e','io.write(_VERSION)'],check=True,capture_output=True,text=True,timeout=10).stdout
    require(version=='Lua 5.1','A real Lua 5.1 interpreter is required, got '+version)
    pins=json.loads((ROOT/'tools/BASE_DEPENDENCY_SHA256.json').read_text('utf-8'))
    for name,expected in pins.items():
        require(hashlib.sha256((base/name).read_bytes()).hexdigest()==expected,'Modified base-addon dependency: '+name)
    data=verify()
    lua_files=sorted(p for p in ROOT.rglob('*.lua') if not any(x in p.parts for x in ('.qa-deps','.qa-results','node_modules','dist','.git')))
    for path in lua_files:
        syntax=subprocess.run([str(luac),'-p',str(path)],capture_output=True,text=True,timeout=20)
        require(syntax.returncode==0,f'Lua 5.1 syntax error in {path.relative_to(ROOT)}: {syntax.stderr}')
    print('PASS: native Lua 5.1 syntax for',len(lua_files),'files; base source pins',len(pins),flush=True)
    scenarios=['fresh','disabled','reset-language','custom-locale','coexist','native-zhCN','corrupt-state','female']
    logs={}
    for scenario in scenarios:
        command=[str(lua),str(ROOT/'tools/tests/runtime.lua'),str(base),str(ROOT),scenario]
        result=subprocess.run(command,capture_output=True,text=True,timeout=60)
        require(result.returncode==0,scenario+' FAILED\n'+result.stdout+'\n'+result.stderr)
        require('PASS\t'+scenario+'\t' in result.stdout,scenario+' did not report success')
        logs[scenario]=result.stdout.strip()
        print(result.stdout.strip(),flush=True)
    # Negative controls: prove that the gate rejects the specific failure
    # classes found during review, rather than only accepting the happy path.
    rejected=[]
    with tempfile.TemporaryDirectory(prefix='pfquest-zhcn-negative-') as temp:
        clone=Path(temp)/'addon'
        shutil.copytree(ROOT,clone,ignore=shutil.ignore_patterns('.git','.qa-deps','.qa-results','node_modules','dist','__pycache__'))
        cases=[
            ('objective_quantity','db/zhCN/quests-epoch.lua','格拉兹要你杀死5个死木战士','格拉兹要你杀死7个死木战士','objective quantity mismatch'),
            ('english_source_drift','db/enUS/units-epoch.lua','Kobold Miner','Changed Kobold Miner','Changed protected English/data source'),
            ('toc_filename_case','pfQuest-epoch.toc','pfquest-arrow.lua','pfQuest-arrow.lua','TOC target missing or wrong case'),
            ('missing_saved_state','pfQuest-epoch.toc','## SavedVariablesPerCharacter: pfQuest_epoch_zhCNCharDB','## RemovedSavedVariables: pfQuest_epoch_zhCNCharDB','Missing character-scoped preference'),
        ]
        cases.extend([
            ('item_name_contamination','db/zhCN/items-epoch.lua','烟林牧场运输箱','钥石：错误副本','Cross-project item-name contamination'),
            ('unclassified_english','db/zhCN/quests-epoch.lua','悬赏河爪豺狼人','悬赏河爪豺狼人 EnglishLeak','Unclassified visible English residue'),
            ('lost_emote_command','db/zhCN/quests-epoch.lua','/bow','/鞠躬','Lost protected quest literal'),
        ])
        for name,relative,before,after,diagnostic in cases:
            file=clone/relative;original=file.read_text('utf-8')
            require(before in original,'Negative test fixture is stale: '+name)
            file.write_text(original.replace(before,after,1),encoding='utf-8')
            result=subprocess.run([os.sys.executable,str(clone/'tools/verify_translation.py')],capture_output=True,text=True,timeout=30)
            file.write_text(original,encoding='utf-8')
            require(result.returncode!=0 and diagnostic in result.stderr,'Gate failed to reject injected '+name)
            rejected.append(name)
    print('PASS: rejected injected failures:',', '.join(rejected),flush=True)
    with tempfile.TemporaryDirectory(prefix='pfquest-zhcn-package-') as temp:
        archives=[Path(temp)/name for name in ('first.zip','second.zip')]
        for dest in archives:
            result=subprocess.run([os.sys.executable,str(ROOT/'tools/package_release.py'),'--output',str(dest)],capture_output=True,text=True,timeout=30)
            require(result.returncode==0,'Packaging failed: '+result.stderr)
        digests=[hashlib.sha256(p.read_bytes()).hexdigest() for p in archives]
        require(digests[0]==digests[1],'Release archive is not deterministic')
        with zipfile.ZipFile(archives[0]) as zipped:
            require(zipped.testzip() is None,'Release archive CRC failure')
            names=set(zipped.namelist())
            require('pfQuest-epoch/LICENSE' in names,'Original LICENSE missing from ZIP')
            require('pfQuest-epoch/localization/compat-epochcn.lua' in names,'Compatibility bridge missing from ZIP')
            require(not any(x.startswith(('tools/','node_modules/','.qa-deps/')) for n in names for x in [n.removeprefix('pfQuest-epoch/')]),'Development files leaked into runtime ZIP')
            count=len(names)
    source_files=[p for p in ROOT.rglob('*') if p.is_file() and p.suffix in ('.lua','.toc','.py') and not any(x in p.parts for x in ('.qa-deps','.qa-results','node_modules','dist','.git','__pycache__'))]
    report={'status':'pass','lua_version':version,'native_lua_source_sha256':LUA_SHA,
        'base_release_sha256':BASE_SHA,'base_lua_files_pinned':len(pins),'syntax_files':len(lua_files),
        'scenarios':logs,'negative_controls_rejected':rejected,'data':data,'deterministic_zip_sha256':digests[0],'zip_file_count':count,
        'tested_source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source_files)},
        'limits':'UI/event objects are test doubles. Core database.lua and selected map methods are actual pinned upstream code. No live game client, renderer, combat-taint or server session was tested.'}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('ALL_CHECKS_PASSED','archive_sha256='+digests[0],'report='+str(args.output),flush=True)

if __name__=='__main__':
    main()
