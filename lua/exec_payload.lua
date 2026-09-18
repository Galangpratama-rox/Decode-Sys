-- ============================================================
-- exec_payload.lua (Updated)
-- Primary: syshub.fun/free (Luraph v14.8 raw Lua)
-- Fallback: Galangpratama-rox JSON-wrapped payload
--
-- Cara pakai:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ZoraRox/SAE-SYS/refs/heads/main/lua/exec_payload.lua"))()
-- ============================================================

-- ── HTTP helper ──────────────────────────────────────────────
local function httpGet(u)
    -- coba game:HttpGet dulu (paling universal)
    local ok, r = pcall(game.HttpGet, game, u, true)
    if ok and type(r) == "string" and #r > 0 then return r end
    -- fallback: request functions
    if syn and syn.request then
        local ok2, r2 = pcall(function() return syn.request({Url=u, Method="GET"}) end)
        if ok2 and r2 and r2.Body and #r2.Body > 0 then return r2.Body end
    end
    if http_request then
        local ok2, r2 = pcall(http_request, {Url=u, Method="GET"})
        if ok2 and r2 and r2.Body and #r2.Body > 0 then return r2.Body end
    end
    if request then
        local ok2, r2 = pcall(request, {Url=u, Method="GET"})
        if ok2 and r2 and r2.Body and #r2.Body > 0 then return r2.Body end
    end
    return nil
end

-- ── Hapus cache lama yang sudah broken ───────────────────────
if isfile and delfile then
    if isfile("syshub_intercept_2.lua") then
        pcall(delfile, "syshub_intercept_2.lua")
        print("[exec] Deleted stale cache: syshub_intercept_2.lua")
    end
end

-- ── Download payload ─────────────────────────────────────────
local CACHE_FILE = "syshub_payload_v2.lua"
local PRIMARY_URL = "https://syshub.fun/free"
local FALLBACK_URL = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/syshub_payload.lua"

local raw = nil
local source = "unknown"

-- 1) Coba dari local cache (versi baru)
if isfile and isfile(CACHE_FILE) then
    raw = readfile(CACHE_FILE)
    source = "local cache"
    print("[exec] Loaded from local cache: " .. CACHE_FILE .. " (" .. #raw .. " bytes)")
end

-- 2) Coba dari syshub.fun/free (primary)
if not raw or #raw < 100 then
    print("[exec] Downloading from primary: " .. PRIMARY_URL)
    raw = httpGet(PRIMARY_URL)
    if raw and #raw > 100 then
        source = "syshub.fun/free"
        print("[exec] Downloaded from syshub.fun/free: " .. #raw .. " bytes")
        -- cache untuk next time
        if writefile then
            pcall(writefile, CACHE_FILE, raw)
            print("[exec] Cached to: " .. CACHE_FILE)
        end
    else
        raw = nil
    end
end

-- 3) Fallback: source lama (JSON wrapped)
if not raw then
    print("[exec] Primary gagal, coba fallback: " .. FALLBACK_URL)
    raw = httpGet(FALLBACK_URL)
    if raw and #raw > 100 then
        source = "fallback (Galangpratama-rox)"
        print("[exec] Downloaded from fallback: " .. #raw .. " bytes")
    else
        raw = nil
    end
end

if not raw or #raw < 100 then
    error("[exec] Gagal mendapatkan payload dari semua sumber!")
end

print("[exec] Source: " .. source)
print("[exec] raw len: " .. #raw)

-- ── Auto-detect format & extract script ──────────────────────
local script = nil

-- Cek apakah JSON wrapped (dimulai dengan { dan ada field "script")
local jsonStart = raw:find('{"', 1, true) or raw:find('{ "', 1, true)
local hasScriptField = raw:find('"script"', 1, true)

if jsonStart and hasScriptField then
    -- Format: JSON wrapped {"status":"...","script":"..."}
    print("[exec] Format: JSON wrapped, extracting script field...")
    local s = raw:find('"script":"', 1, true)
    if not s then
        s = raw:find('"script" : "', 1, true)
        if s then s = s + 2 end -- adjust offset
    end
    if not s then error("[exec] field 'script' tidak ditemukan di JSON") end

    local content = raw:sub(s + 10)
    local i = 1
    local result = {}

    while i <= #content do
        local c = content:sub(i, i)
        if c == '"' then
            break
        elseif c == '\\' then
            local nx = content:sub(i+1, i+1)
            if nx == 'n' then
                table.insert(result, '\n'); i = i + 2
            elseif nx == 'r' then
                i = i + 2
            elseif nx == 't' then
                table.insert(result, '\t'); i = i + 2
            elseif nx == '"' then
                table.insert(result, '"'); i = i + 2
            elseif nx == '/' then
                table.insert(result, '/'); i = i + 2
            elseif nx == '\\' then
                table.insert(result, '\\'); i = i + 2
            elseif nx == 'u' then
                if content:sub(i+2, i+2) == '{' then
                    local close = content:find('}', i+3, true)
                    if close then
                        table.insert(result, content:sub(i, close))
                        i = close + 1
                    else
                        table.insert(result, '\\u'); i = i + 2
                    end
                else
                    table.insert(result, content:sub(i, i+5))
                    i = i + 6
                end
            else
                table.insert(result, '\\')
                table.insert(result, nx)
                i = i + 2
            end
        else
            table.insert(result, c)
            i = i + 1
        end
    end

    script = table.concat(result)
    print("[exec] Extracted script: " .. #script .. " chars")
else
    -- Format: Raw Lua script (syshub.fun/free returns ini)
    print("[exec] Format: raw Lua script")
    script = raw
end

print("[exec] script len: " .. #script)

-- ── Loadstring & Execute ─────────────────────────────────────
local fn, err = loadstring(script)
if not fn then
    local errmsg = tostring(err or "unknown error")
    local linenum = tonumber(errmsg:match(":(%d+):"))
    if linenum then
        print("[exec] Error near line " .. linenum .. ":")
        local line = 0
        for l in script:gmatch("[^\n]+") do
            line = line + 1
            if line >= linenum-1 and line <= linenum+1 then
                print("  line " .. line .. ": " .. l:sub(1, 200))
            end
        end
    end
    error("[exec] loadstring gagal: " .. errmsg)
end

print("[exec] Executing payload...")
local ok, runerr = pcall(fn)
if not ok then
    error("[exec] Runtime error: " .. tostring(runerr))
end
print("[exec] Done.")
