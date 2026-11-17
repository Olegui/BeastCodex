"""Checks every locale file against Locales/enUS.lua.  py tools/check_locales.py

Each translation must define exactly the English keys (minus the ones listed
in SHARED, which are the same in every language) and keep the same format
placeholders in the same order.
"""
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = {"TITLE", "LEVEL_UNKNOWN"}
PLACEHOLDER = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[a-zA-Z]")


def read(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    pairs = re.findall(r'(?:^|[\s,{])(?:L\.)?([A-Z][A-Za-z0-9_]*)\s*=\s*"((?:[^"\\]|\\.)*)"', text)
    return dict(pairs)


def main():
    base = read(os.path.join(ROOT, "Locales", "enUS.lua"))
    want = set(base) - SHARED
    problems = []
    files = sorted(glob.glob(os.path.join(ROOT, "Locales", "*.lua")))
    for path in files:
        name = os.path.basename(path)
        if name == "enUS.lua":
            continue
        loc = read(path)
        for k in sorted(want - set(loc)):
            problems.append("%s: missing %s" % (name, k))
        for k in sorted(set(loc) - set(base)):
            problems.append("%s: unknown key %s" % (name, k))
        for k in sorted(want & set(loc)):
            if PLACEHOLDER.findall(base[k]) != PLACEHOLDER.findall(loc[k]):
                problems.append("%s: placeholders differ in %s" % (name, k))
    print("\n".join(problems) or "%d locale files match enUS (%d keys)" % (len(files) - 1, len(want)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
