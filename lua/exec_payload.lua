-- ============================================================
-- exec_payload.lua - Langsung execute decoded payload
-- TANPA key, TANPA bypass, langsung ke main script
--
-- Flow:
--   1. Download decoded payload (yang sudah di-capture)
--   2. Extract script dari JSON (jika wrapped)
--   3. loadstring + execute → langsung jalan
--
-- Cara pakai:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/refs/heads/main/lua/exec_payload.lua"))()
-- ============================================================

-- ── HTTP helper ──────────────────────────────────────────────
local function httpGet(u)
    local ok, r = pcall(game.HttpGet, game, u, true)
    if ok and type(r) == "string" and #r > 0 then return r end
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

-- ── Hapus cache lama ─────────────────────────────────────────
if isfile and delfile then
    for _, old in ipairs({"syshub_intercept_2.lua", "syshub_payload_v2.lua", "syshub_payload_v3.lua"}) do
        if isfile(old) then
            pcall(delfile, old)
            print("[exec] Deleted old cache: " .. old)
        end
    end
end

-- ── Download decoded payload ─────────────────────────────────
local CACHE_FILE = "syshub_decoded.lua"
-- URL ini harus mengarah ke DECODED payload (hasil capture)
-- Setelah capture, upload ke GitHub dan update URL ini
local PAYLOAD_URL = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/syshub_captured_payload.lua"
local FALLBACK_URL = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/syshub_payload.lua"

local raw = nil
local source = "unknown"

-- 1) Coba dari local cache
if isfile and isfile(CACHE_FILE) then
    raw = readfile(CACHE_FILE)
    if raw and #raw > 100 then
        source = "local cache"
        print("[exec] Loaded from cache (" .. #raw .. " bytes)")
    else
        raw = nil
    end
end

-- 2) Download decoded payload baru
if not raw then
    print("[exec] Downloading decoded payload...")
    raw = httpGet(PAYLOAD_URL)
    if raw and #raw > 100 then
        source = "captured payload"
        print("[exec] Downloaded: " .. #raw .. " bytes")
        if writefile then pcall(writefile, CACHE_FILE, raw) end
    else
        raw = nil
    end
end

-- 3) Fallback: payload lama
if not raw then
    print("[exec] Trying fallback...")
    raw = httpGet(FALLBACK_URL)
    if raw and #raw > 100 then
        source = "fallback"
        print("[exec] Fallback downloaded: " .. #raw .. " bytes")
    else
        raw = nil
    end
end

if not raw or #raw < 100 then
    error("[exec] Gagal mendapatkan decoded payload!")
end

print("[exec] Source: " .. source)
print("[exec] raw len: " .. #raw)

-- ── Extract script (auto-detect format) ──────────────────────
local script = nil

if raw:find('{"', 1, true) and raw:find('"script"', 1, true) then
    -- Format: JSON wrapped {"script":"..."}
    print("[exec] Format: JSON wrapped")
    local s = raw:find('"script":"', 1, true)
    if not s then error("[exec] field script not found") end

    local content = raw:sub(s + 10)
    local i = 1
    local result = {}
    while i <= #content do
        local c = content:sub(i, i)
        if c == '"' then break
        elseif c == '\\' then
            local nx = content:sub(i+1, i+1)
            if nx == 'n' then table.insert(result, '\n'); i = i + 2
            elseif nx == 'r' then i = i + 2
            elseif nx == 't' then table.insert(result, '\t'); i = i + 2
            elseif nx == '"' then table.insert(result, '"'); i = i + 2
            elseif nx == '/' then table.insert(result, '/'); i = i + 2
            elseif nx == '\\' then table.insert(result, '\\'); i = i + 2
            elseif nx == 'u' then
                if content:sub(i+2, i+2) == '{' then
                    local close = content:find('}', i+3, true)
                    if close then table.insert(result, content:sub(i, close)); i = close + 1
                    else table.insert(result, '\\u'); i = i + 2 end
                else table.insert(result, content:sub(i, i+5)); i = i + 6 end
            else table.insert(result, '\\'); table.insert(result, nx); i = i + 2 end
        else table.insert(result, c); i = i + 1 end
    end
    script = table.concat(result)
    print("[exec] Extracted: " .. #script .. " chars")
else
    -- Format: raw Lua
    print("[exec] Format: raw Lua")
    script = raw
end

-- ── Execute ──────────────────────────────────────────────────
local fn, err = loadstring(script)
if not fn then
    error("[exec] loadstring gagal: " .. tostring(err))
end

print("[exec] Executing...")
local ok, runerr = pcall(fn)
if not ok then
    error("[exec] Runtime error: " .. tostring(runerr))
end
print("[exec] Done.")
