-- ============================================================
-- SysHub Payload Capturer
-- Jalankan DULU, lalu jalankan syshub.fun/free + masukkan key
-- Script ini akan capture decoded payload yang dikirim API
-- dan simpan sebagai file + print ke console
--
-- Cara pakai:
-- 1. Jalankan script ini
-- 2. Jalankan: loadstring(game:HttpGet("https://syshub.fun/free"))()
-- 3. Masukkan key: FREE-SYS-PQNJ-9HPK-9HHZ
-- 4. Lihat output [CAPTURE] di console
-- 5. File tersimpan sebagai syshub_captured_payload.lua
-- ============================================================

local captured = {}
local count = 0

-- ── Wrap semua HTTP functions ────────────────────────────────
local function wrapFn(fn, name)
    if not fn or type(fn) ~= "function" then return nil end
    return function(opts)
        local res = fn(opts)
        if res and res.Body and #res.Body > 50 then
            count = count + 1
            local url = ""
            if type(opts) == "table" then
                url = tostring(opts.Url or opts.url or "unknown")
            elseif type(opts) == "string" then
                url = opts
            end

            print("[CAPTURE #" .. count .. "] " .. name .. " | URL: " .. url)
            print("[CAPTURE #" .. count .. "] Body len: " .. #res.Body)
            print("[CAPTURE #" .. count .. "] Preview: " .. res.Body:sub(1, 300))

            captured[count] = { url = url, body = res.Body, via = name }

            -- Simpan setiap response ke file
            local fname = "syshub_capture_" .. count .. ".lua"
            pcall(function()
                if writefile then
                    writefile(fname, res.Body)
                    print("[CAPTURE #" .. count .. "] Saved: " .. fname)
                end
            end)

            -- Cek apakah ini payload utama (JSON dengan field "script")
            if res.Body:find('"script"', 1, true) then
                print("[CAPTURE #" .. count .. "] >>> INI KEMUNGKINAN DECODED PAYLOAD! <<<")
                pcall(function()
                    if writefile then
                        writefile("syshub_captured_payload.lua", res.Body)
                        print("[CAPTURE] Saved payload to: syshub_captured_payload.lua")
                    end
                end)
            end

            -- Cek apakah ini raw Lua code
            if res.Body:find("^%s*%-%-") or res.Body:find("^%s*local ") 
               or res.Body:find("^%s*return ") or res.Body:find("function") then
                print("[CAPTURE #" .. count .. "] >>> INI KEMUNGKINAN LUA CODE! <<<")
                pcall(function()
                    if writefile then
                        writefile("syshub_captured_lua_" .. count .. ".lua", res.Body)
                        print("[CAPTURE] Saved lua code to: syshub_captured_lua_" .. count .. ".lua")
                    end
                end)
            end
        end
        return res
    end
end

-- Hook semua HTTP methods
local ge = getgenv and getgenv() or {}

if rawget(ge, "http_request") then
    local orig = rawget(ge, "http_request")
    rawset(ge, "http_request", wrapFn(orig, "http_request"))
    print("[CAPTURE] Hooked: http_request")
end
if rawget(ge, "request") then
    local orig = rawget(ge, "request")
    rawset(ge, "request", wrapFn(orig, "request"))
    print("[CAPTURE] Hooked: request")
end
if rawget(ge, "httprequest") then
    local orig = rawget(ge, "httprequest")
    rawset(ge, "httprequest", wrapFn(orig, "httprequest"))
    print("[CAPTURE] Hooked: httprequest")
end
if syn and type(syn) == "table" and syn.request then
    syn.request = wrapFn(syn.request, "syn.request")
    print("[CAPTURE] Hooked: syn.request")
end

-- Hook game:HttpGet juga
local _origHttpGet = game.HttpGet
if hookfunction then
    local old = hookfunction(game.HttpGet, newcclosure(function(self, url, ...)
        local result = _origHttpGet(self, url, ...)
        if type(result) == "string" and #result > 50 then
            count = count + 1
            print("[CAPTURE #" .. count .. "] HttpGet | URL: " .. tostring(url))
            print("[CAPTURE #" .. count .. "] Body len: " .. #result)
            print("[CAPTURE #" .. count .. "] Preview: " .. result:sub(1, 300))

            captured[count] = { url = tostring(url), body = result, via = "HttpGet" }

            local fname = "syshub_capture_" .. count .. ".lua"
            pcall(function()
                if writefile then
                    writefile(fname, result)
                    print("[CAPTURE #" .. count .. "] Saved: " .. fname)
                end
            end)

            if result:find('"script"', 1, true) then
                print("[CAPTURE #" .. count .. "] >>> DECODED PAYLOAD! <<<")
                pcall(function()
                    if writefile then
                        writefile("syshub_captured_payload.lua", result)
                    end
                end)
            end

            if result:find("function") or result:find("local ") then
                print("[CAPTURE #" .. count .. "] >>> LUA CODE! <<<")
                pcall(function()
                    if writefile then
                        writefile("syshub_captured_lua_" .. count .. ".lua", result)
                    end
                end)
            end
        end
        return result
    end))
    print("[CAPTURE] Hooked: game:HttpGet via hookfunction")
else
    print("[CAPTURE] WARNING: hookfunction not available, game:HttpGet NOT hooked")
end

-- Global helpers
_G.showCaptures = function()
    if count == 0 then
        print("[CAPTURE] Belum ada yang ter-capture.")
        return
    end
    for i, v in pairs(captured) do
        print("--- #" .. i .. " ---")
        print("Via : " .. v.via)
        print("URL : " .. v.url)
        print("Len : " .. #v.body)
        print("Body: " .. v.body:sub(1, 200))
        print("")
    end
end

_G.getCapture = function(n)
    return captured[n] and captured[n].body
end

print("")
print("========================================")
print("[CAPTURE] Semua hooks aktif!")
print("[CAPTURE] Sekarang jalankan SysHub:")
print('  loadstring(game:HttpGet("https://syshub.fun/free"))()')
print("[CAPTURE] Masukkan key dan lihat output capture.")
print("[CAPTURE] Setelah selesai, ketik: showCaptures()")
print("========================================")
print("")
