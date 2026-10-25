#!/usr/bin/env python3
"""Package the runtime addon, excluding development sources and external dependencies."""
import argparse
import hashlib
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

root=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,default=root/'dist/pfQuest-epoch-zhCN-v3.3.0-rc.1.zip')
args=parser.parse_args()
files=[]
for p in root.rglob('*'):
    if not p.is_file():continue
    relative=p.relative_to(root)
    if p.suffix.lower() in ('.pyc',):continue
    if len(relative.parts) == 1:
        if p.suffix == '.lua' or p.name in ('pfQuest-epoch.toc','LICENSE','README.md'):
            files.append(p)
    elif relative.parts[0] in ('db','init','img'):
        files.append(p)
    elif relative.parts[0] == 'localization' and (p.suffix == '.lua' or p.name in ('LICENSE-pfQuest-MIT.txt','LICENSE-LibBabble-MIT.txt')):
        files.append(p)
args.output.parent.mkdir(parents=True,exist_ok=True)
with ZipFile(args.output,'w',compression=ZIP_DEFLATED,compresslevel=9) as archive:
    for path in sorted(files):
        rel='pfQuest-epoch/'+path.relative_to(root).as_posix()
        zi=ZipInfo(rel,date_time=(2026,10,26,0,0,0))
        zi.compress_type=ZIP_DEFLATED
        zi.external_attr=0o644<<16
        archive.writestr(zi,path.read_bytes())
with ZipFile(args.output) as archive:
    assert archive.testzip() is None
    members=set(archive.namelist())
    assert 'pfQuest-epoch/pfQuest-epoch.toc' in members
    assert 'pfQuest-epoch/db/zhCN/quests-epoch.lua' in members
    assert 'pfQuest-epoch/localization/zhCN.lua' in members
    assert not any('/tools/' in x or '/.github/' in x or '/.git/' in x for x in members)
print('PACKAGED',args.output,'files',len(files),'bytes',args.output.stat().st_size,'sha256',hashlib.sha256(args.output.read_bytes()).hexdigest())
