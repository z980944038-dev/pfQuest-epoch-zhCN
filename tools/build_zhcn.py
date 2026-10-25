#!/usr/bin/env python3
"""Rebuild pfQuest-epoch's Simplified Chinese data from pinned, attributable sources.

Usage: python3 tools/build_zhcn.py --epochcn-data DIR --base-enus DIR --base-zhcn-zip ZIP

Only source-backed text is emitted; unverified translations remain English fallbacks.
The English quest search database must never be rewritten by this script.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import re
import zipfile
from pathlib import Path

HAN = re.compile(r"[\u3400-\u9fff]")
ROW = re.compile(r"(?m)^\s*\[(\d+)\]\s*=\s*\{")
NAMED = re.compile(r'\["([TOD])"\]\s*=\s*')
SIMPLE_ID = re.compile(r'\[(\d+)\]\s*=\s*(["\'])')
SIMPLE_NAME = re.compile(r'\[(["\'])')


def parse_lua_quoted(data: str, start: int) -> tuple[str, int]:
    quote = data[start]
    if quote not in ('"', "'"):
        raise ValueError(f"Expected quoted Lua string at offset {start}")
    parts = []
    idx = start + 1
    escapes = {"n": "\n", "r": "\r", "t": "\t", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", '"': '"', "'": "'"}
    while idx < len(data):
        char = data[idx]
        if char == quote:
            return "".join(parts), idx + 1
        if char != "\\":
            parts.append(char)
            idx += 1
            continue
        idx += 1
        if idx >= len(data):
            raise ValueError("Unterminated Lua escape")
        esc = data[idx]
        if esc.isascii() and esc.isdigit():
            digits = re.match(r"\d{1,3}", data[idx:])
            code = int(digits.group(0))
            if code > 255:
                raise ValueError("Out of range Lua numeric escape")
            parts.append(chr(code))
            idx += len(digits.group(0))
        elif esc in escapes:
            parts.append(escapes[esc])
            idx += 1
        elif esc == "\n":
            parts.append("\n")
            idx += 1
        else:
            raise ValueError(f"Unsupported Lua escape \\{esc} at {idx}")
    raise ValueError("Unterminated Lua quoted string")


def parse_list_rows(data: str) -> dict[int, list[str]]:
    """Read numeric ID = {"literal", ...} records, no Lua execution."""
    rows = {}
    for match in ROW.finditer(data):
        i, values = match.end(), []
        while i < len(data):
            while i < len(data) and (data[i].isspace() or data[i] == ','):
                i += 1
            if data[i] == '}':
                break
            if data[i] in ('"', "'"):
                text, i = parse_lua_quoted(data, i)
                values.append(text)
            elif data.startswith("nil", i):
                values.append("")
                i += 3
            else:
                # Ignore nested/unsupported records (not silently misparse them).
                raise ValueError(f"Nonliteral list row id={match.group(1)} at offset {i}: {data[i:i+32]}")
        ident = int(match.group(1))
        if ident in rows:
            raise ValueError(f"Duplicate row ID {ident}")
        rows[ident] = values
    return rows



def parse_first_rows(data: str) -> dict[int, list[str]]:
    """Read a first quoted name from entries that also contain nested metadata."""
    rows = {}
    for match in ROW.finditer(data):
        index = match.end()
        while index < len(data) and data[index].isspace():
            index += 1
        if index >= len(data) or data[index] not in ('"', "'"):
            continue
        value, _ = parse_lua_quoted(data, index)
        ident = int(match.group(1))
        # Some legacy EpochCN lists contain duplicate IDs; Lua uses the last value.
        rows[ident] = [value]
    return rows


def parse_id_strings(data: str) -> dict[int, str]:
    result = {}
    for match in SIMPLE_ID.finditer(data):
        ident = int(match.group(1))
        value, _ = parse_lua_quoted(data, match.end() - 1)
        if ident in result and result[ident] != value:
            raise ValueError(f"Duplicate conflicting ID {ident}")
        result[ident] = value
    return result


def parse_english_quests(data: str) -> dict[int, dict[str, str]]:
    found = {}
    matches = list(ROW.finditer(data))
    for n, match in enumerate(matches):
        segment = data[match.end():matches[n+1].start() if n+1 < len(matches) else len(data)]
        fields = {}
        for field in NAMED.finditer(segment):
            position = field.end()
            while position < len(segment) and segment[position].isspace():
                position += 1
            if segment[position] not in ('"', "'"):
                continue
            value, _ = parse_lua_quoted(segment, position)
            fields[field.group(1)] = value
        ident = int(match.group(1))
        if not {'T', 'O', 'D'}.issubset(fields):
            raise ValueError(f"Missing T/O/D for quest ID {ident}")
        found[ident] = fields
    return found


def parse_names(data: str) -> dict[str, str]:
    """Read ["English name"] = "Chinese name" pairs, including Lua escaped quotes."""
    mapping = {}
    for match in SIMPLE_NAME.finditer(data):
        en, end = parse_lua_quoted(data, match.end()-1)
        tail = re.match(r"\s*\]\s*=\s*", data[end:])
        if not tail:
            continue
        cursor = end + tail.end()
        if cursor < len(data) and data[cursor] in ('"', "'"):
            zh, _ = parse_lua_quoted(data, cursor)
            mapping[en] = zh
    return mapping


def lua_quote(value: str) -> str:
    return '"' + (value.replace('\\', '\\\\').replace('"', '\\"')
                  .replace('\n', '\\n').replace('\r', '\\r')
                  .replace('\t', '\\t').replace('\0', '\\000')) + '"'


def locale_block(text: str, name: str) -> str:
    match = re.search(r'\["'+re.escape(name)+r'"\]\s*=\s*\{', text)
    if not match:
        raise ValueError(f"Missing locale {name}")
    opening = match.end()-1
    level = 0
    i = opening
    while i < len(text):
        char = text[i]
        if char in ('"', "'"):
            _, i = parse_lua_quoted(text, i)
            continue
        if char == '{':
            level += 1
        elif char == '}':
            level -= 1
            if level == 0:
                return text[opening:i+1]
        i += 1
    raise ValueError(f"Unterminated locale {name}")


def verify_source_english(source: dict[int, str], vanilla: dict[int, str], ident: int) -> bool:
    # Protect against reused IDs: never transplant a vanilla translation
    # when Project Epoch changed the English name for that ID.
    return ident in vanilla and source[ident].casefold() == vanilla[ident].casefold()


def emit_string_table(path: Path, category: str, entries: dict[int, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [f'-- Generated from EpochCN and Shagu pfQuest 7.0.1; see localization/SOURCES.json.',
             f'pfDB["{category}"]["zhCN-epoch"] = {{']
    for ident, translation in sorted(entries.items()):
        lines.append(f'  [{ident}] = {lua_quote(translation)},')
    lines.append('}')
    path.write_text('\n'.join(lines)+'\n', encoding='utf-8')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--epochcn-data', type=Path, required=True)
    parser.add_argument('--base-enus', type=Path, required=True)
    parser.add_argument('--base-zhcn-zip', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    db = root / 'db'
    cd = args.epochcn_data

    originals = parse_english_quests((db/'enUS/quests-epoch.lua').read_text('utf-8'))
    if len(originals) != 2390:
        raise ValueError(f"Unexpected upstream quest count: {len(originals)}")
    epoch = parse_list_rows((cd/'EpochQuestData.lua').read_text('utf-8'))
    general = parse_list_rows((cd/'QuestCN_Data.lua').read_text('utf-8'))
    item_epoch = parse_first_rows((cd/'EpochItemData.lua').read_text('utf-8'))
    items_general = parse_first_rows((cd/'ItemData.lua').read_text('utf-8'))
    units_general = parse_first_rows((cd/'UnitData.lua').read_text('utf-8'))
    names_items = parse_names((cd/'ItemNameMap.lua').read_text('utf-8'))
    names_objects = parse_names((cd/'ObjectiveNameData.lua').read_text('utf-8'))
    names_head = parse_names((cd/'EpochHeadData.lua').read_text('utf-8'))

    expected_zip = "c4b2ff2d4e767739d63f7424f53d6ddb24157bfaf2d60e542f7a4bc1a85cb0a1"
    actual_zip = hashlib.sha256(args.base_zhcn_zip.read_bytes()).hexdigest()
    if actual_zip != expected_zip:
        raise ValueError("Base Chinese release SHA256 differs from the reviewed 7.0.1 asset")
    zhvanilla, envanilla = {}, {}
    with zipfile.ZipFile(args.base_zhcn_zip) as ref:
        members = set(ref.namelist())
        for cat in ['items', 'units', 'objects', 'zones']:
            zhvanilla[cat], envanilla[cat] = {}, {}
            # The release's TBC tables carry hundreds of valid localized zone names.
            for suffix in ('', '-tbc', '-wotlk'):
                for language, target in [('zhCN', zhvanilla[cat]), ('enUS', envanilla[cat])]:
                    name = f'pfQuest-wotlk/db/{language}/{cat}{suffix}.lua'
                    if name in members:
                        for ident, value in parse_id_strings(ref.read(name).decode('utf-8')).items():
                            if value == '_':
                                target.pop(ident, None)
                            else:
                                target[ident] = value
    reviewed = json.loads((root/'localization/REVIEWED_OVERRIDES.json').read_text('utf-8'))
    def apply_review(kind, ident, field, original, fallback):
        if kind == 'quests':
            entry = reviewed['quests'].get(str(ident), {}).get(field)
        else:
            entry = reviewed['names'].get(kind, {}).get(str(ident))
        if not entry:
            return fallback
        actual = hashlib.sha256(original.encode('utf-8')).hexdigest()
        if actual != entry['source_sha256']:
            raise ValueError(f"Reviewed English source changed: {kind}:{ident}:{field}")
        return entry['text']

    # Names are keyed by their English text as well as stable IDs. If a server
    # reuses an ID, an exact English-name match avoids attaching the wrong CN.
    by_english = {}
    for category in ['items', 'units', 'objects', 'zones']:
        candidates = collections.defaultdict(set)
        for ident, english in envanilla[category].items():
            chinese = zhvanilla[category].get(ident)
            if chinese and HAN.search(chinese) and english:
                candidates[english.casefold()].add(chinese)
        by_english[category] = {k: next(iter(vals)) for k, vals in candidates.items() if len(vals) == 1}

    # Four EpochCN entries retained untranslated English titles; the
    # corrections below are localized names, not changes to numeric IDs.
    manual_quest_titles = {
        27273: "沙格里",
        27298: "嗅探器 MK IV",
        27451: "传说讲述者范扎",
        27931: "火酿的佳酿",
    }
    output_quests = {}
    quest_flags = []
    from_epoch = 0
    for ident, english in sorted(originals.items()):
        row, source = (epoch.get(ident), 'EpochCN-Epoch') if ident in epoch else (general.get(ident), 'EpochCN-general')
        if not row or len(row) < 3:
            quest_flags.append({'quest_id': ident, 'issue': 'No Chinese source record', 'source': source})
            continue
        if ident in manual_quest_titles:
            row = list(row)
            row[0] = manual_quest_titles[ident]
        if not HAN.search(row[0]):
            quest_flags.append({'quest_id': ident, 'issue': 'No Chinese title', 'source': source})
            continue
        if source == 'EpochCN-Epoch' and len(row) >= 5 and row[4].strip().casefold() != english['T'].strip().casefold():
            quest_flags.append({'quest_id':ident,'issue':'English title differs from source; manual review required',
                                'en_upstream':english['T'],'en_epochcn':row[4]})
        translated = {}
        for index, field in enumerate(['T','O','D']):
            text = apply_review('quests', ident, field, english[field], row[index] or '')
            if english[field] == '':
                translated[field] = ''
            elif text and HAN.search(text):
                translated[field] = text
            else:
                translated[field] = english[field]
                if english[field]:
                    quest_flags.append({'quest_id': ident, 'issue': 'Missing translated '+field})
        output_quests[ident] = translated
        if source == 'EpochCN-Epoch':
            from_epoch += 1
    lines = ['-- Generated by tools/build_zhcn.py; preserve English data for server lookups.',
             'pfDB["quests"]["zhCN-epoch"] = {']
    for ident, tr in sorted(output_quests.items()):
        lines.append('  ['+str(ident)+'] = { '+', '.join(f'["{key}"] = {lua_quote(tr[key])}' for key in ['T','O','D'])+' },')
    lines.append('}')
    (db/'zhCN/quests-epoch.lua').write_text('\n'.join(lines)+'\n', encoding='utf-8')

    counts = {}
    all_localized = {}
    for cat in ['items', 'units', 'objects', 'zones']:
        ens = parse_id_strings((db/f'enUS/{cat}-epoch.lua').read_text('utf-8'))
        localized = {}
        for ident, english in sorted(ens.items()):
            options = []
            if cat == 'items':
                for records in [item_epoch, items_general]:
                    row = records.get(ident)
                    if row and row[0]:
                        options.append(row[0])
                options += [names_items.get(english), names_head.get(english)]
            elif cat == 'units':
                row = units_general.get(ident)
                if row: options.append(row[0])
            elif cat == 'objects':
                options += [names_objects.get(english), names_head.get(english)]
            if verify_source_english(ens, envanilla[cat], ident):
                options.append(zhvanilla[cat].get(ident))
            options.append(by_english[cat].get(english.casefold()))
            translation = next((name for name in options if name and HAN.search(name)), None)
            translation = apply_review(cat, ident, None, english, translation)
            if translation:
                localized[ident] = translation
        all_localized[cat] = localized
        emit_string_table(db/f'zhCN/{cat}-epoch.lua', cat, localized)
        counts[cat] = {'translated':len(localized),'total':len(ens),'untranslated':len(ens)-len(localized)}

    # Resolve embedded English proper names from the same attributable locale
    # sources. Only exact, unambiguous names at word boundaries are replaced.
    glossary_candidates = collections.defaultdict(set)
    for cat in ['items', 'units', 'objects', 'zones']:
        epoch_english = parse_id_strings((db/f'enUS/{cat}-epoch.lua').read_text('utf-8'))
        for source_en, source_zh in [(envanilla[cat], zhvanilla[cat]), (epoch_english, all_localized[cat])]:
            for ident, english_name in source_en.items():
                chinese_name = source_zh.get(ident)
                if (english_name and len(english_name) >= 4 and chinese_name and HAN.search(chinese_name)
                        and not any(char in english_name for char in '|\n\r')):
                    glossary_candidates[english_name].add(chinese_name)
    buckets = collections.defaultdict(list)
    for name, choices in glossary_candidates.items():
        if len(choices) == 1:
            buckets[name[:3]].append((name, next(iter(choices))))
    for values in buckets.values():
        values.sort(key=lambda pair: (-len(pair[0]), pair[0]))
    glossary_changes = 0
    for ident, record in output_quests.items():
        for field, text in record.items():
            if not HAN.search(text):
                continue
            chunks, cursor = [], 0
            for word in re.finditer(r"(?<![A-Za-z0-9_])[A-Z][A-Za-z']*", text):
                start = word.start()
                if start < cursor:
                    continue
                for name, translated_name in buckets.get(text[start:start+3], []):
                    end = start + len(name)
                    if text.startswith(name, start) and (end == len(text) or not re.match(r'[A-Za-z0-9_]', text[end])):
                        chunks.extend((text[cursor:start], translated_name))
                        cursor = end
                        glossary_changes += 1
                        break
            chunks.append(text[cursor:])
            record[field] = ''.join(chunks)
    lines = ['-- Generated by tools/build_zhcn.py; English identities remain untouched.', 'pfDB["quests"]["zhCN-epoch"] = {']
    for ident, record in sorted(output_quests.items()):
        fields = ', '.join(f'["{key}"] = {lua_quote(record[key])}' for key in ['T','O','D'])
        lines.append(f'  [{ident}] = {{ {fields} }},')
    lines.append('}')
    (db/'zhCN/quests-epoch.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')

    # The professions overlay is intentionally empty in upstream.
    (db/'zhCN/professions-epoch.lua').write_text('pfDB["professions"]["zhCN-epoch"] = {}\n',encoding='utf-8')
    init = ['<Ui xmlns="http://www.blizzard.com/wow/ui/">']
    for cat in ['items','units','objects','quests','zones','professions']:
        init.append(f'  <Include file="..\\db\\zhCN\\{cat}-epoch.lua"/>')
    init.append('</Ui>')
    (root/'init/zhCN-epoch.xml').write_text('\n'.join(init)+'\n',encoding='utf-8')

    # pfQuest's own Simplified Chinese UI localization (MIT), kept verbatim.
    base_ui=(args.base_enus/'locales.lua').read_text('utf-8')
    ui=locale_block(base_ui,'zhCN')
    (root/'localization/zhCN-ui.lua').write_text(
        '-- UI phrases taken from shagu/pfQuest 7.0.1, MIT license (see SOURCES.json).\n'
        'pfQuestEpochZhCN_UI = '+ui+'\n',encoding='utf-8')

    summary={'base':'Bennylavaa/pfQuest-epoch v3.3.0',
             'epochcn_reference_commit':'2ef292670df80c58672674adfc3fd0798661c862',
             'shagu_pfquest_release':'7.0.1',
             'shagu_zhcn_zip_sha256':hashlib.sha256(args.base_zhcn_zip.read_bytes()).hexdigest(),
             'total_epoch_quest_ids':len(originals), 'translated_quest_ids':len(output_quests),
             'epochcn_specific_quest_matches':from_epoch,
             'general_quest_matches':len(output_quests)-from_epoch,
             'quest_review_flags':quest_flags, 'name_coverage':counts,
             'reviewed_quest_fields':sum(len(v) for v in reviewed['quests'].values()),
             'reviewed_name_entries':{k:len(v) for k,v in reviewed['names'].items()},
             'localization_version':'zhCN-beta.2',
             'exact_proper_name_substitutions':glossary_changes,
             'source_caveats':[{'quest_id':28705,'issue':'English objective places Ratchet in Silverpine Forest; CN keeps Ratchet, omits contradictory region. Original data untouched.'}],
             'note':'ID equality is not proof of semantic correctness. English server index is retained. No live game runtime test.'}
    (root/'localization/TRANSLATION_REPORT.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    manifest={'original':'https://github.com/Bennylavaa/pfQuest-epoch',
              'original_license':'Custom, personal use and GitHub forks only',
              'epochcn':'https://github.com/z980944038-dev/EpochCN',
              'epochcn_commit':summary['epochcn_reference_commit'],
              'pfquest_core':'https://github.com/shagu/pfQuest',
              'pfquest_core_release':'7.0.1','pfquest_core_license':'MIT',
              'usage':'Derived translation data only; no complete third-party addon redistributed.',
              'reviewed_overrides_sha256':hashlib.sha256((root/'localization/REVIEWED_OVERRIDES.json').read_bytes()).hexdigest(),
              'input_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(cd.glob('*.lua'))},
              'manual_names':'Community localization, not an official translation or proof of live-server correctness.'}
    (root/'localization/SOURCES.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'quest_total':len(originals),'quest_chinese':len(output_quests),'flags':len(quest_flags),'name_coverage':counts},indent=2,ensure_ascii=False))


if __name__ == '__main__':
    main()
