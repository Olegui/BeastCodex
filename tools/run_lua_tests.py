"""Runs the addon's self-checks outside the game, in Lua 5.1.

    .cache/venv/Scripts/python tools/run_lua_tests.py

Every .lua file in the .toc is compiled (syntax check). The addon's own
files are executed against a tiny stub of the WoW API (their top level only
defines functions), then ns.tests run. Frame-building code is not exercised:
that needs the real client.
"""
import os, sys

from lupa import lua51

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = "Libs"  # third-party libraries are compiled but not executed

STUB = r"""
-- Every frame, texture and font string is a fresh stub: any method call works
-- and returns another stub, and fields the addon sets on it stay on that object.
local mt = {}
local function new() return setmetatable({}, mt) end
mt.__index = function(_, key)
  if key == "GetStringWidth" then return function() return 50 end end -- code does arithmetic on it
  return function() return new() end
end
mt.__call = function() return new() end
local noop = new()
function GetLocale() return TEST_LOCALE end
function CreateFrame() return new() end
function LibStub() return nil end
function date() return "test" end
SlashCmdList, UISpecialFrames, C_Timer = {}, {}, noop
C_Map = { GetMapInfo = function(id) return { name = "Map " .. id } end }
WorldMapFrame, UIParent, GameTooltip = noop, noop, noop
function print() end
function tinsert(t, v) table.insert(t, v) end
function ReloadUI() end
"""


SMOKE = """function(ns)
    -- Builds and refreshes the window under every theme against stub frames.
    local problems = {}
    for name in pairs(ns.Themes) do
        ns.db = ns.SanitizeDB({ theme = name }, ns.Creatures)
        ns.ApplyTheme(name)
        ns.Window.frame = nil
        local ok, err = pcall(function()
            ns.Window:Create()
            ns.Window:Refresh()
            ns.Detail:Pin(ns.Creatures[1])
            ns.Detail:Preview(nil)
        end)
        if not ok then problems[#problems + 1] = "window under theme " .. name .. ": " .. tostring(err) end
    end
    return table.concat(problems, "\\n")
end"""


def run_locale(locale):
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TEST_LOCALE = locale
    lua.execute(STUB)
    ns = lua.eval("{}")
    load = lua.eval("function(src, name) return loadstring(src, name) end")
    with open(os.path.join(ROOT, "BeastCodex.toc"), encoding="utf-8") as f:
        files = [l.strip() for l in f if l.strip().endswith(".lua")]
    bad = 0
    for rel in files:
        path = os.path.join(ROOT, rel.replace("\\", os.sep))
        with open(path, encoding="utf-8") as f:
            res = load(f.read(), "@" + rel)
        # loadstring returns the chunk alone on success, (nil, message) on a syntax error
        chunk, err = res if isinstance(res, tuple) else (res, None)
        if chunk is None:
            print("SYNTAX", err)
            bad += 1
        elif not rel.startswith(SKIP):
            try:
                chunk("BeastCodex", ns)
            except Exception as e:  # a load-time error is a failure too
                print("LOAD", rel, e)
                bad += 1
    run = lua.eval("""function(ns)
        local failed, total = {}, 0
        for _, t in ipairs(ns.tests or {}) do
            total = total + 1
            local ok, err = pcall(t[2])
            if not ok then failed[#failed + 1] = t[1] .. ": " .. tostring(err) end
        end
        return total, table.concat(failed, "\\n")
    end""")
    total, failed = run(ns)
    smoke = lua.eval(SMOKE)(ns)
    if smoke:
        failed = (failed + "\n" if failed else "") + smoke
    fails = [l for l in failed.split("\n") if l]
    for l in fails:
        print("FAIL", l)
    print("%s: %d files compiled, %d checks, %d failed" % (locale, len(files), total, len(fails) + bad))
    return 1 if fails or bad else 0


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    # English plus two translated clients: checks must not depend on English text.
    return max(run_locale(loc) for loc in ("enUS", "ptBR", "zhCN"))


if __name__ == "__main__":
    sys.exit(main())
