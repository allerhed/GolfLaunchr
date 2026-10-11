#!/bin/bash
# Every key in every .xcstrings must have a non-empty, translated 'en' and 'sv' value.
cd "$(dirname "$0")/.."
python3 -I - <<'PY'
import json,glob,sys
bad=0; files=glob.glob('App/**/*.xcstrings',recursive=True)+glob.glob('Packages/**/*.xcstrings',recursive=True)
if not files: print("l10n: no catalogs found"); sys.exit(1)
for f in files:
    d=json.load(open(f))
    for k,v in d.get('strings',{}).items():
        if v.get('shouldTranslate') is False: continue
        loc=v.get('localizations',{})
        for lang in ('en','sv'):
            u=loc.get(lang,{})
            ok = u.get('stringUnit',{}).get('value') or u.get('variations')
            st=u.get('stringUnit',{}).get('state','translated')
            if not ok or st not in ('translated',):
                print(f"l10n: {f}: '{k}' missing/untranslated [{lang}]"); bad=1
print("l10n ok" if not bad else "l10n FAILED"); sys.exit(bad)
PY
