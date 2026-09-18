-- ============================================================
-- SysHub Bypass Loader (Updated)
-- Primary: syshub.fun/free (Luraph v14.8 raw Lua)
-- Fallback: Galangpratama-rox sources
--
-- Cara pakai:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ZoraRox/SAE-SYS/refs/heads/main/lua/loader.lua"))()
-- ============================================================

-- ── HTTP helper ──────────────────────────────────────────────
local function httpGet(u)
    -- coba game:HttpGet dulu
    local ok, r = pcall(game.HttpGet, game, u, true)
    if ok and type(r) == "string" and #r > 0 then return r end
    -- fallback chain
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
    if http and http.request then
        local ok2, r2 = pcall(http.request, {Url=u, Method="GET"})
        if ok2 and r2 and r2.Body and #r2.Body > 0 then return r2.Body end
    end
    return nil
end

-- ── Hapus cache lama yang sudah broken ───────────────────────
if isfile and delfile then
    if isfile("syshub_intercept_2.lua") then
        pcall(delfile, "syshub_intercept_2.lua")
        print("[Loader] Deleted stale cache: syshub_intercept_2.lua")
    end
end

-- ── Download payload ─────────────────────────────────────────
local CACHE_FILE = "syshub_payload_v2.lua"
local PRIMARY_URL = "https://syshub.fun/free"
local FALLBACK_URL_1 = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/syshub_free_raw.lua"
local FALLBACK_URL_2 = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/syshub_payload.lua"

local payload = nil
local source = "unknown"

-- 1) Coba dari local cache (versi baru)
if isfile and isfile(CACHE_FILE) then
    local raw = readfile(CACHE_FILE)
    if raw and #raw > 100 then
        payload = raw
        source = "local cache"
        print("[Loader] Loaded from cache: " .. CACHE_FILE .. " (" .. #raw .. " bytes)")
    end
end

-- 2) Coba dari syshub.fun/free (primary - returns raw Lua)
if not payload then
    print("[Loader] Downloading from primary: " .. PRIMARY_URL)
    local raw = httpGet(PRIMARY_URL)
    if raw and #raw > 100 then
        payload = raw
        source = "syshub.fun/free"
        print("[Loader] Downloaded from syshub.fun/free: " .. #raw .. " bytes")
        -- cache untuk next time
        if writefile then
            pcall(writefile, CACHE_FILE, raw)
            print("[Loader] Cached to: " .. CACHE_FILE)
        end
    end
end

-- 3) Fallback: syshub_free_raw.lua
if not payload then
    print("[Loader] Trying fallback 1: " .. FALLBACK_URL_1)
    local raw = httpGet(FALLBACK_URL_1)
    if raw and #raw > 100 then
        -- strip komentar baris pertama jika ada
        if raw:sub(1, 2) == "--" then
            raw = raw:gsub("^[^\n]*\n", "", 1)
        end
        payload = raw
        source = "fallback (syshub_free_raw.lua)"
        print("[Loader] Downloaded from fallback 1: " .. #raw .. " bytes")
    end
end

-- 4) Fallback: JSON wrapped syshub_payload.lua
if not payload then
    print("[Loader] Trying fallback 2: " .. FALLBACK_URL_2)
    local raw = httpGet(FALLBACK_URL_2)
    if raw and #raw > 100 then
        -- Auto-detect: JSON wrapped vs raw Lua
        local hasScript = raw:find('"script"', 1, true)
        if hasScript then
            -- Extract dari JSON
            local s = raw:find('"script":"', 1, true)
            if s then
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
                payload = table.concat(result)
                source = "fallback (JSON wrapped)"
                print("[Loader] Extracted from JSON: " .. #payload .. " chars")
            end
        else
            payload = raw
            source = "fallback (raw)"
            print("[Loader] Loaded raw fallback: " .. #raw .. " bytes")
        end
    end
end

if not payload then
    error("[Loader] Gagal mendapatkan payload dari semua sumber!")
end

print("[Loader] Source: " .. source)
print("[Loader] Payload: " .. #payload .. " chars")

-- ── Eksekusi payload ─────────────────────────────────────────
local fn, err = loadstring(payload)
if not fn then
    error("[Loader] loadstring error: " .. tostring(err))
end

print("[Loader] Executing payload...")
local ok, runerr = pcall(fn)
if not ok then
    error("[Loader] Runtime error: " .. tostring(runerr))
end
print("[Loader] Done.")
