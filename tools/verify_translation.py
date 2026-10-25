#!/usr/bin/env python3
"""Validate all locale IDs, source hashes, quantities, template controls and TOC paths."""
from __future__ import annotations
import collections
import hashlib
import json
import re
from pathlib import Path
from build_zhcn import parse_english_quests, parse_id_strings, HAN
from audit_english import audit as audit_english

ROOT=Path(__file__).resolve().parent.parent

def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)

def controls(text: str, pattern: str) -> collections.Counter:
    return collections.Counter(token.upper() for token in re.findall(pattern,text))

def verify() -> dict:
    baseline=json.loads((ROOT/'tools/BASELINE_SHA256.json').read_text('utf-8'))
    for filename,expected in baseline.items():
        path=ROOT/filename
        require(path.is_file(),f'Missing protected source: {filename}')
        require(hashlib.sha256(path.read_bytes()).hexdigest()==expected,f'Changed protected English/data source: {filename}')
    require(hashlib.sha256((ROOT/'LICENSE').read_bytes()).hexdigest()=='bc3751ef444f570aed70bb3b2575622f441f62ce9148abe32eac4c5b5f45b1cd','Original LICENSE changed')
    en=parse_english_quests((ROOT/'db/enUS/quests-epoch.lua').read_text('utf-8'))
    zh=parse_english_quests((ROOT/'db/zhCN/quests-epoch.lua').read_text('utf-8'))
    require(len(en)==2390 and set(en)==set(zh),'Quest IDs must match all 2390 upstream entries')
    findings=[]
    for ident,source in en.items():
        for field in ('T','O','D'):
            text=zh[ident][field]; original=source[field]
            if original:
                if not HAN.search(text):findings.append([ident,field,'missing Chinese text'])
            elif text:
                findings.append([ident,field,'invented text for an empty upstream field'])
            for name,pattern in [('player',r'\$[NnCcRr]'),('printf',r'%[sdif]'),('colors',r'\|[cC][0-9a-fA-F]{8}|\|r'),('link-payload',r'\|H[^|]*\|h')]:
                if controls(text,pattern)!=controls(original,pattern):findings.append([ident,field,name+' control mismatch'])
            gender=lambda value:re.findall(r'\$[Gg][^:;]*:[^;]*;',value)
            if len(gender(text))!=len(gender(original)):findings.append([ident,field,'gender branch count mismatch'])
            if re.search(r'\$[Gg]',re.sub(r'\$[Gg][^:;]*:[^;]*;','',text)):findings.append([ident,field,'invalid gender syntax'])
            if re.search(r'\bPH\d+\b|[“\"]NL[”\"]|\ufffd',text):findings.append([ident,field,'placeholder debris or corrupt Unicode'])
            if field=='O':
                clean=lambda value:re.sub(r'\|[cC][0-9A-Fa-f]{8}|\|r','',value)
                nums=lambda value:collections.Counter(re.findall(r'(?<![A-Za-z])\d+(?:\.\d+)?',clean(value)))
                if nums(text)!=nums(original):findings.append([ident,field,'objective quantity mismatch'])
    require(not findings,'Translation hard failures: '+json.dumps(findings,ensure_ascii=False))
    overrides=json.loads((ROOT/'localization/REVIEWED_OVERRIDES.json').read_text('utf-8'))
    for ident,fields in overrides['quests'].items():
        for field,entry in fields.items():
            require(hashlib.sha256(en[int(ident)][field].encode()).hexdigest()==entry['source_sha256'],f'Reviewed source drift: quest {ident}:{field}')
    coverage={};remaining={}
    for kind in ('items','units','objects','zones'):
        a=parse_id_strings((ROOT/f'db/enUS/{kind}-epoch.lua').read_text('utf-8'))
        c=parse_id_strings((ROOT/f'db/zhCN/{kind}-epoch.lua').read_text('utf-8'))
        require(set(c)<=set(a),'Unexpected ID in '+kind)
        require(all(HAN.search(v) for v in c.values()),'Non-Chinese name in translated table: '+kind)
        for ident,entry in overrides['names'].get(kind,{}).items():
            require(hashlib.sha256(a[int(ident)].encode()).hexdigest()==entry['source_sha256'],f'Reviewed name source drift: {kind}:{ident}')
        coverage[kind]={'translated':len(c),'total':len(a),'untranslated':len(a)-len(c)}
        remaining[kind]=[{'id':id,'english':value} for id,value in a.items() if id not in c]
    report=json.loads((ROOT/'localization/TRANSLATION_REPORT.json').read_text('utf-8'))
    require(report['name_coverage']==coverage,'Stale translation coverage report')
    require(not report['quest_review_flags'],'Source import still contains unresolved missing quest fields')
    text=(ROOT/'pfQuest-epoch.toc').read_text('utf-8')
    require(text.index('localization\\compat-epochcn.lua')<text.index('patchtable.lua'),'API bridge must capture base methods before Epoch wrappers')
    require(text.index('patchtable.lua')<text.index('init\\zhCN-epoch.xml')<text.index('localization\\zhCN.lua'),'Chinese runtime data must load after all upstream merges')
    require('## SavedVariablesPerCharacter: pfQuest_epoch_zhCNCharDB' in text,'Missing character-scoped preference')
    actual={p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file()}
    require(len(actual)==len({p.casefold() for p in actual}),'Case-insensitive filename collision')
    for line in text.splitlines():
        line=line.strip()
        if line and not line.startswith('#'):
            require(line.replace('\\','/') in actual,'TOC target missing or wrong case: '+line)
    for xml in (ROOT/'init').glob('*.xml'):
        for target in re.findall(r'file="([^"]+)"',xml.read_text('utf-8')):
            path=(xml.parent/target.replace('\\','/')).resolve()
            require(path.is_relative_to(ROOT.resolve()),'XML include escapes addon root')
            require(path.relative_to(ROOT.resolve()).as_posix() in actual,'XML target missing or wrong case: '+target)
    require('_, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle' not in (ROOT/'pfQuest-tooltip.lua').read_text(),'7th-value completion bug reintroduced')
    residual_audit=audit_english()
    # 已校订译名必须与产物逐字一致，不能只核对原文哈希。
    for kind,entries in overrides['names'].items():
        generated=parse_id_strings((ROOT/f'db/zhCN/{kind}-epoch.lua').read_text('utf-8'))
        for ident,entry in entries.items():
            require(generated.get(int(ident))==entry['text'],f'Reviewed output mismatch: {kind}:{ident}')
    version=re.search(r'^## X-Localization-Version: (.+)$',text,re.M).group(1).strip()
    require(report['localization_version']==version,'Localization version mismatch')
    runtime=(ROOT/'localization/zhCN.lua').read_text('utf-8')
    require(('version = "'+version+'"') in runtime,'Runtime version mismatch')
    require((ROOT/'localization/LICENSE-LibBabble-MIT.txt').is_file(),'Missing LibBabble MIT attribution')
    for ident,fields in overrides['quests'].items():
        for field,entry in fields.items():
            for literal in entry.get('preserve_literals',[]):
                require(literal in zh[int(ident)][field],f'Generated text lost protected literal: {ident}:{field}')
    return {'quest_ids':len(en),'quest_fields':len(en)*3,'source_baselines':len(baseline),'critical_data_failures':0,
            'english_residual_audit':residual_audit,
            'name_coverage':coverage,'remaining_names':remaining,'live_game_tested':False}

if __name__=='__main__':
    result=verify()
    print('PASS: IDs, English SHA256 baselines, quantity/template controls, reviewed source pins, LICENSE and manifest paths')
    print(json.dumps({k:v for k,v in result.items() if k!='remaining_names'},ensure_ascii=False))
