#!/usr/bin/env python3
"""Verify localized IDs, unchanged source structure and additive TOC loading."""
import hashlib
import json
from pathlib import Path
from build_zhcn import parse_english_quests, parse_id_strings

root = Path(__file__).resolve().parent.parent
baseline = json.loads((root/'tools/BASELINE_SHA256.json').read_text('utf-8'))
for filename, digest in baseline.items():
    path = root / filename
    assert path.is_file(), filename
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, f"English upstream modified: {filename}"
eng = parse_english_quests((root/'db/enUS/quests-epoch.lua').read_text('utf-8'))
cn = parse_english_quests((root/'db/zhCN/quests-epoch.lua').read_text('utf-8'))
assert len(eng) == 2390, len(eng)
assert set(eng) == set(cn), f"Missing/extra quest IDs: {set(eng) ^ set(cn)}"
for ident, entry in cn.items():
    assert entry['T'].strip(), ident
    assert set(entry) == {'T','O','D'}, ident
for kind in ('items','units','objects','zones'):
    english = parse_id_strings((root/f'db/enUS/{kind}-epoch.lua').read_text('utf-8'))
    chinese = parse_id_strings((root/f'db/zhCN/{kind}-epoch.lua').read_text('utf-8'))
    assert set(chinese) <= set(english), kind
manifest = json.loads((root/'localization/TRANSLATION_REPORT.json').read_text('utf-8'))
assert manifest['total_epoch_quest_ids'] == manifest['translated_quest_ids'] == 2390
assert manifest['epochcn_specific_quest_matches'] + manifest['general_quest_matches'] == 2390
text = (root/'pfQuest-epoch.toc').read_text('utf-8')
assert text.index('init\\enUS-epoch.xml') < text.index('init\\zhCN-epoch.xml') < text.index('patchtable.lua')
assert text.index('patchtable.lua') < text.index('localization\\zhCN-ui.lua') < text.index('localization\\zhCN.lua')
for f in ('db/zhCN/quests-epoch.lua','localization/zhCN.lua','localization/zhCN-ui.lua','localization/LICENSE-pfQuest-MIT.txt'):
    assert (root/f).is_file(), f
print('PASS: 2390 quest IDs, supplemental locale data, original English SHA-256 baselines, load order')
print('COVERAGE:',json.dumps(manifest['name_coverage'],ensure_ascii=False))
print('REVIEW_FLAGS:',len(manifest['quest_review_flags']))
