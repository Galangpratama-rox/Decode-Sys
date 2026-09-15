-- ============================================================
-- SysHub Payload Executor
-- Jalankan ini setelah intercept berhasil (ada syshub_intercept_2.lua)
-- ============================================================

local raw = readfile("syshub_intercept_2.lua")
print("Raw len: " .. #raw)

-- JSON formatnya: {"status":"success","message":"...","script":"<LUA CODE>"}
-- field "script" dimulai setelah  "script":"  dan diakhiri dengan  "}
-- karena isi script sangat panjang, kita cari posisi awal dan akhirnya

local startMarker = '"script":"'
local startPos = raw:find(startMarker, 1, true)

if not startPos then
    error("Tidak ditemukan field 'script' di response!")
end

-- posisi awal konten script (setelah marker)
local contentStart = startPos + #startMarker

-- cari akhir: karakter " yang tidak di-escape (diawali bukan \)
-- scan dari belakang — JSON diakhiri  ..."}
-- cara paling simpel: potong dari akhir, hapus  "}
local contentRaw = raw:sub(contentStart)

-- hapus trailing  "}  atau  "}  dengan whitespace
contentRaw = contentRaw:match('^(.*)"[^"]*}%s*$') or contentRaw:match('^(.*)"[}]%s*$') or contentRaw

-- kalau masih ada trailing quote, hapus
if contentRaw:sub(-1) == '"' then
    contentRaw = contentRaw:sub(1, -2)
end

print("Raw script len: " .. #contentRaw)

-- unescape JSON string
local script = contentRaw
script = script:gsub('\\r\\n', '\n')
script = script:gsub('\\r',   '\n')
script = script:gsub('\\n',   '\n')
script = script:gsub('\\t',   '\t')
script = script:gsub('\\/',   '/')
script = script:gsub('\\"',   '"')
script = script:gsub('\\\\',  '\\')

print("Script len after unescape: " .. #script)
print("Preview: " .. script:sub(1, 150))

-- execute
local fn, err = loadstring(script)
if not fn then
    error("loadstring error: " .. tostring(err))
end

print("Executing payload...")
fn()
