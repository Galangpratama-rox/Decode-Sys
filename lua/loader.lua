-- SysHub Loader
-- Cara pakai di executor Roblox:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/loader.lua"))()

local url = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-Sys/main/lua/syshub_free_raw.lua"

local function getContent(u)
    -- coba semua method HTTP yang umum di berbagai executor
    if syn and syn.request then
        local r = syn.request({Url=u, Method="GET"})
        if r and r.Body and #r.Body > 0 then return r.Body end
    end
    if http and http.request then
        local r = http.request({Url=u, Method="GET"})
        if r and r.Body and #r.Body > 0 then return r.Body end
    end
    if request then
        local r = request({Url=u, Method="GET"})
        if r and r.Body and #r.Body > 0 then return r.Body end
    end
    if http_request then
        local r = http_request({Url=u, Method="GET"})
        if r and r.Body and #r.Body > 0 then return r.Body end
    end
    -- fallback HttpGet
    local ok, result = pcall(function()
        return game:HttpGet(u, true)
    end)
    if ok and result and #result > 0 then return result end
    -- fallback HttpGetAsync
    local ok2, result2 = pcall(function()
        return game:HttpGetAsync(u)
    end)
    if ok2 and result2 and #result2 > 0 then return result2 end
    return nil
end

local src = getContent(url)
if not src then
    error("[SysHub Loader] Gagal mengambil script dari: " .. url)
end

-- strip baris pertama (komentar anti-theft) kalau ada
local firstLine = src:match("^([^\n]*)\n")
if firstLine and firstLine:find("--") then
    src = src:gsub("^[^\n]*\n", "", 1)
end

-- load dan eksekusi
local fn, err = loadstring(src)
if not fn then
    error("[SysHub Loader] loadstring error: " .. tostring(err))
end

-- panggil dengan environment Roblox yang lengkap
local env = getfenv and getfenv() or _ENV
fn(env)
