-- ============================================================
-- exec_payload.lua (Updated v2)
-- Inject Luarmor bypass DULU, baru execute syshub.fun/free
--
-- Primary: syshub.fun/free (Luraph v14.8 raw Lua)
-- Fallback: Galangpratama-rox JSON-wrapped payload
--
-- Cara pakai:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ZoraRox/SAE-SYS/refs/heads/main/lua/exec_payload.lua"))()
-- ============================================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.1)

local ge = getgenv and getgenv() or {}
local cenv = getfenv and getfenv(1) or _ENV or {}

-- ══════════════════════════════════════════════════════════════
-- STEP 1: INJECT LUARMOR / JNKIE BYPASS (fakeReq)
-- ══════════════════════════════════════════════════════════════
do
    local native_http_request = rawget(ge, "http_request")
    local native_request      = rawget(ge, "request")
    local native_syn_request  = (syn and rawget(syn, "request")) or nil
    local native_httprequest  = rawget(ge, "httprequest")
    local native_syn_ref      = syn

    local function jsonEncode(t)
        local ok, hs = pcall(function() return game:GetService("HttpService") end)
        if ok and hs then
            local ok2, r = pcall(function() return hs:JSONEncode(t) end)
            if ok2 then return r end
        end
        return "{}"
    end

    local function fakeRes(body)
        return { StatusCode = 200, Status = 200, Body = body,
                 Headers = { ["Content-Type"] = "application/json" } }
    end

    local function buildFakeReq(origReq)
        return function(opts)
            local url = type(opts) == "table"
                and tostring(opts.Url or opts.url or "") or tostring(opts or "")
            local u = url:lower()

            -- Intercept luarmor.net dan jnkie.com
            if u:find("luarmor%.net") or u:find("jnkie%.com") then
                local sid  = "bf-" .. tostring(math.random(1e6, 9e6))
                local stok = "bf-tok-" .. tostring(math.random(1e6, 9e6))

                if u:find("check") or u:find("auth") or u:find("access") or u:find("validate") then
                    return fakeRes(jsonEncode({
                        status = "success", success = true, valid = true, authorized = true,
                        message = "OK",
                        data = {
                            mode = "public_maintenance",
                            accessTier = "premium", licenseType = "premium",
                            sessionId = sid, sessionToken = stok,
                            nextHeartbeatSeconds = 999999,
                            continuityCredential = "bf-bypass"
                        }
                    }))
                end
                if u:find("heartbeat") then
                    return fakeRes(jsonEncode({ status = "success", state = "active", success = true }))
                end
                if u:find("challenge") then
                    return fakeRes(jsonEncode({
                        status = "success",
                        transportKey = string.rep("61", 32),
                        challengeId = "bf-chal-" .. sid,
                        success = true
                    }))
                end
                if u:find("maintenance") or u:find("session") or u:find("login") then
                    return fakeRes(jsonEncode({
                        status = "success", success = true,
                        session = {
                            sessionId = sid, sessionToken = stok,
                            nextHeartbeatSeconds = 999999,
                            accessTier = "premium", licenseType = "premium"
                        },
                        continuityCredential = "bf-bypass",
                        accessTier = "premium", licenseType = "premium"
                    }))
                end
                return fakeRes(jsonEncode({ status = "success", success = true, message = "Bypassed" }))
            end

            -- Non-luarmor URL: forward ke original request
            if type(origReq) == "function" then return origReq(opts) end
            return { StatusCode = 0, Status = 0, Body = "" }
        end
    end

    local function pickNative()
        if type(native_http_request) == "function" then return native_http_request end
        if type(native_request)      == "function" then return native_request end
        if type(native_syn_request)  == "function" then return native_syn_request end
        if type(native_httprequest)  == "function" then return native_httprequest end
        return nil
    end

    local native  = pickNative()
    local fakeReq = buildFakeReq(native)

    -- Inject ke semua global HTTP functions
    rawset(ge, "request", fakeReq)
    rawset(ge, "http_request", fakeReq)
    rawset(ge, "httprequest", fakeReq)
    rawset(ge, "__BFBypassReq", fakeReq)
    rawset(ge, "__BigFrootBypassActive", true)

    if native_syn_ref and type(native_syn_ref) == "table" then
        rawset(native_syn_ref, "request", fakeReq)
    end

    _G.request = fakeReq
    _G.http_request = fakeReq
    if cenv and cenv ~= ge and cenv ~= _G then
        pcall(function() rawset(cenv, "request", fakeReq) end)
        pcall(function() rawset(cenv, "http_request", fakeReq) end)
    end

    -- Set ACTUAL SysHub Free key (bukan random)
    local actualKey = "FREE-SYS-PQNJ-9HPK-9HHZ"
    ge.script_key = actualKey
    ge.SCRIPT_KEY = actualKey
    _G.script_key = actualKey
    _G.SCRIPT_KEY = actualKey
    -- Set juga variasi nama yang mungkin dipakai
    ge.Key = actualKey
    ge.key = actualKey
    _G.Key = actualKey
    _G.key = actualKey
    ge.ScriptKey = actualKey
    _G.ScriptKey = actualKey

    print("[exec] Bypass injected (luarmor.net, jnkie.com)")
    print("[exec] script_key: " .. actualKey)
end

-- ══════════════════════════════════════════════════════════════
-- STEP 1.5: HTTP REQUEST LOGGING (capture semua traffic)
-- ══════════════════════════════════════════════════════════════
do
    local _wrappedReq = ge.request or _G.request
    if type(_wrappedReq) == "function" then
        local loggingReq = function(opts)
            local url = ""
            if type(opts) == "table" then
                url = tostring(opts.Url or opts.url or "unknown")
            elseif type(opts) == "string" then
                url = opts
            end
            print("[HTTP LOG] >>> " .. url)
            local res = _wrappedReq(opts)
            if res and res.Body then
                print("[HTTP LOG] <<< " .. #res.Body .. " bytes | " .. tostring(res.Body):sub(1, 200))
            end
            return res
        end
        rawset(ge, "request", loggingReq)
        rawset(ge, "http_request", loggingReq)
        _G.request = loggingReq
        _G.http_request = loggingReq
        if syn and type(syn) == "table" then
            rawset(syn, "request", loggingReq)
        end
        print("[exec] HTTP logging active")
    end
end

-- ══════════════════════════════════════════════════════════════
-- STEP 2: HTTP HELPER (pakai game:HttpGet native, bukan fakeReq)
-- ══════════════════════════════════════════════════════════════
local _nativeHttpGet = game.HttpGet

local function httpGet(u)
    local ok, r = pcall(_nativeHttpGet, game, u, true)
    if ok and type(r) == "string" and #r > 0 then return r end
    -- Fallback: request functions (sudah di-wrap fakeReq,
    -- tapi untuk non-luarmor URL akan forward ke origReq)
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

-- ══════════════════════════════════════════════════════════════
-- STEP 3: HAPUS CACHE LAMA & DOWNLOAD PAYLOAD
-- ══════════════════════════════════════════════════════════════

-- Hapus cache lama yang broken
if isfile and delfile then
    if isfile("syshub_intercept_2.lua") then
        pcall(delfile, "syshub_intercept_2.lua")
        print("[exec] Deleted stale cache: syshub_intercept_2.lua")
    end
end

local CACHE_FILE = "syshub_payload_v2.lua"
local PRIMARY_URL = "https://syshub.fun/free"
local FALLBACK_URL = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/syshub_payload.lua"

local raw = nil
local source = "unknown"

-- 1) Coba dari local cache (versi baru)
if isfile and isfile(CACHE_FILE) then
    raw = readfile(CACHE_FILE)
    source = "local cache"
    print("[exec] Loaded from cache: " .. CACHE_FILE .. " (" .. #raw .. " bytes)")
end

-- 2) Coba dari syshub.fun/free (primary)
if not raw or #raw < 100 then
    print("[exec] Downloading from primary: " .. PRIMARY_URL)
    raw = httpGet(PRIMARY_URL)
    if raw and #raw > 100 then
        source = "syshub.fun/free"
        print("[exec] Downloaded from syshub.fun/free: " .. #raw .. " bytes")
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

-- ══════════════════════════════════════════════════════════════
-- STEP 4: AUTO-DETECT FORMAT & EXTRACT SCRIPT
-- ══════════════════════════════════════════════════════════════
local script = nil

local jsonStart = raw:find('{"', 1, true) or raw:find('{ "', 1, true)
local hasScriptField = raw:find('"script"', 1, true)

if jsonStart and hasScriptField then
    -- Format: JSON wrapped {"status":"...","script":"..."}
    print("[exec] Format: JSON wrapped, extracting script field...")
    local s = raw:find('"script":"', 1, true)
    if not s then
        s = raw:find('"script" : "', 1, true)
        if s then s = s + 2 end
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
    -- Format: Raw Lua script (syshub.fun/free)
    print("[exec] Format: raw Lua script")
    script = raw
end

print("[exec] script len: " .. #script)

-- ══════════════════════════════════════════════════════════════
-- STEP 5: LOADSTRING & EXECUTE
-- ══════════════════════════════════════════════════════════════
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

print("[exec] Executing payload (bypass active)...")
local ok, runerr = pcall(fn)
if not ok then
    error("[exec] Runtime error: " .. tostring(runerr))
end
print("[exec] Done.")
