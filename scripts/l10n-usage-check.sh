#!/bin/bash
# Localisation usage check: every semantic key used in App code exists in the String Catalog (a missing key shows the raw key to the
# user), and every catalog key is used somewhere (stale keys are reported, dynamic key families are allowed). Also checks that English
# and Swedish use the same placeholders and that the Swedish glossary terms are present.
cd "$(dirname "$0")/.."
python3 -I - <<'PY'
import json, re, glob, sys
cat = json.load(open('App/Localizable.xcstrings'))['strings']
base = {k.split(' ')[0] for k in cat}
namespaces = {k.split('.')[0] for k in base}
code = ''
for f in glob.glob('App/**/*.swift', recursive=True) + glob.glob('Packages/*/Sources/**/*.swift', recursive=True):
    code += open(f).read() + '\n'
# Strip contexts where a dotted string is an identifier, not a localised key.
stripped = re.sub(r'accessibilityIdentifier\("[^"]*"\)', '', code)
stripped = re.sub(r'systemName:\s*"[^"]*"', '', stripped)
stripped = re.sub(r'\bid:\s*"[^"]*"', '', stripped)
stripped = re.sub(r'forKey:\s*"[^"]*"', '', stripped)
stripped = re.sub(r'suiteName:\s*"[^"]*"', '', stripped)
stripped = re.sub(r'scrollTo\("[^"]*"', '', stripped)
stripped = re.sub(r'\.id\("[^"]*"\)', '', stripped)
stripped = re.sub(r'static let \w+ = "[^"]*"', '', stripped)  # UserDefaults keys and similar constants
stripped = re.sub(r'//[^\n]*', '', stripped)
literals = set(re.findall(r'"([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)(?: %[^"]*|\s*\\\([^"]*)?"', stripped))
ignore_prefixes = ('harness.',)  # Debug harness text is English-only by design and never ships
missing = sorted(l for l in literals if l.split('.')[0] in namespaces and l not in base and not l.startswith(ignore_prefixes) and not l.endswith('.fill'))
bad = 0
for m in missing:
    print(f"l10n-usage: key used in code but missing from the catalog: {m}"); bad = 1
# Keys built at run time from enum raw values are allowed to look unused.
dynamic = re.compile(r'^(setup\.(blocker|warning)\.|setup\.check\.|setup\.state\.|capability\.|history\.range\.|appearance\.|unit\.|provenance\.|metric\.|seed\.club\.|quality\.|failure\.|mode\.)')
for k in sorted(base):
    if k in literals or dynamic.match(k): continue
    if re.search(r'"' + re.escape(k) + r'(["\s]|\\)', code): continue
    print(f"l10n-usage: catalog key never referenced (stale?): {k}")
# Placeholders must match between languages.
spec = re.compile(r'%(?:\d+\$)?(?:l+d|@|d|f|\.\df)')
def values(loc):
    if 'stringUnit' in loc: return [loc['stringUnit']['value']]
    return [v['stringUnit']['value'] for dim in loc.get('variations', {}).values() for v in dim.values()]
for k, v in cat.items():
    sets = {}
    for lang in ('en', 'sv'):
        sets[lang] = {tuple(sorted(re.sub(r'\d+\$', '', s) for s in spec.findall(x))) for x in values(v['localizations'][lang])}
    if sets['en'] != sets['sv']:
        print(f"l10n-usage: placeholder mismatch en/sv: {k}"); bad = 1
# Swedish glossary (spec F25): reviewed terms must be the ones used.
glossary = {'metric.carry': 'Flyglängd', 'metric.ballSpeed': 'Bollhastighet', 'metric.clubSpeed': 'Klubbhastighet',
            'provenance.measured': 'Uppmätt', 'provenance.estimated': 'Beräknad', 'provenance.unavailable': 'Inte tillgängligt'}
for k, term in glossary.items():
    got = cat[k]['localizations']['sv']['stringUnit']['value']
    if term not in got:
        print(f"l10n-usage: glossary term for {k} is '{got}', expected '{term}'"); bad = 1
print("l10n-usage ok" if not bad else "l10n-usage FAILED")
sys.exit(bad)
PY
