#!/usr/bin/env python3
"""Report untranslated ASCII in shipped Chinese data, with exact reviewed exceptions.

Original enUS data, code/API identifiers, protocols, URLs and developer diagnostics
are intentionally not counted as untranslated player-facing Chinese database text.
"""
from __future__ import annotations
import hashlib
import json
import re
from pathlib import Path
from build_zhcn import parse_english_quests, parse_id_strings

ROOT=Path(__file__).resolve().parent.parent

def visible(text: str) -> str:
    text=re.sub(r'\|[cC][0-9a-fA-F]{8}|\|r','',text)
    text=re.sub(r'\$[NnCcRrBb]','',text)
    # Both gender branches are displayed conditionally: inspect their contents.
    text=re.sub(r'\$[Gg]([^:]*):([^;]*);',lambda m:m[1]+' '+m[2],text)
    return text

def audit() -> dict:
    policy=json.loads((ROOT/'localization/PRESERVED_TEXT.json').read_text('utf-8'))
    english=parse_english_quests((ROOT/'db/enUS/quests-epoch.lua').read_text('utf-8'))
    chinese=parse_english_quests((ROOT/'db/zhCN/quests-epoch.lua').read_text('utf-8'))
    unresolved=[];preserved=[];checked=0
    for ident,record in chinese.items():
        for field,text in record.items():
            checked+=1
            entry=policy['quests'].get(f'{ident}:{field}')
            remaining=text
            if entry:
                if hashlib.sha256(english[ident][field].encode()).hexdigest()!=entry['source_sha256']:
                    raise ValueError(f'Preserved quest literal source drift: {ident}:{field}')
                for literal in entry['literals']:
                    if literal not in text or literal not in english[ident][field]:
                        raise ValueError(f'Lost protected quest literal: {ident}:{field}')
                    remaining=remaining.replace(literal,'')
                preserved.append({'kind':'quests','id':ident,'field':field,'reason':entry['reason'],'literals':entry['literals']})
            tokens=re.findall(r"[A-Za-z][A-Za-z0-9'’-]*(?:[ \t]+[A-Za-z][A-Za-z0-9'’-]*)*",visible(remaining))
            if tokens:unresolved.append({'kind':'quests','id':ident,'field':field,'tokens':tokens})
    names_checked={};special=[];contamination=[]
    for kind in ('items','units','objects','zones'):
        source=parse_id_strings((ROOT/f'db/enUS/{kind}-epoch.lua').read_text('utf-8'))
        localized=parse_id_strings((ROOT/f'db/zhCN/{kind}-epoch.lua').read_text('utf-8'))
        names_checked[kind]=len(localized)
        for ident,en in source.items():
            if ident not in localized:
                entry=policy['untranslated_objects'].get(str(ident)) if kind=='objects' else None
                if not entry or entry['english']!=en:
                    unresolved.append({'kind':kind,'id':ident,'reason':'missing translated name','english':en})
                else:
                    special.append({'id':ident,'english':en,'reason':entry['reason']})
                continue
            text=localized[ident]
            if kind=='items' and '钥石' in text and 'keystone' not in en.lower():
                contamination.append({'id':ident,'english':en,'chinese':text})
            remaining=text
            entry=policy['names'].get(kind,{}).get(str(ident))
            if entry:
                if hashlib.sha256(en.encode()).hexdigest()!=entry['source_sha256'] or text!=entry['display']:
                    raise ValueError(f'Reviewed technical identifier changed: {kind}:{ident}')
                for literal in entry['literals']:remaining=remaining.replace(literal,'')
                preserved.append({'kind':kind,'id':ident,'reason':entry['reason'],'literals':entry['literals']})
            tokens=re.findall('[A-Za-z]+',visible(remaining))
            if tokens:unresolved.append({'kind':kind,'id':ident,'tokens':tokens})
    if contamination:raise ValueError('Cross-project item-name contamination: '+json.dumps(contamination,ensure_ascii=False))
    if unresolved:raise ValueError('Unclassified visible English residue: '+json.dumps(unresolved,ensure_ascii=False))
    return {'status':'pass','quest_fields_checked':checked,'localized_names_checked':names_checked,
            'unclassified_residuals':0,'known_item_name_contamination':0,
            'preserved_technical_or_fictional_entries':preserved,'untranslated_special_objects':special,
            'scope':'Chinese quest/entity database strings; original English matching tables, code/protocol keys, URLs, brand names and developer diagnostics are outside this metric.',
            'semantic_review_complete':False,'live_game_tested':False}

if __name__=='__main__':
    print(json.dumps(audit(),ensure_ascii=False,indent=2))
