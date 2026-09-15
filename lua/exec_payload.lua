-- ============================================================
-- SysHub Payload Executor
-- Jalankan ini setelah intercept berhasil (ada syshub_intercept_2.lua)
-- ============================================================

local raw = readfile("syshub_intercept_2.lua")
print("Raw len: " .. #raw)

-- response formatnya JSON: {"status":"success","message":"Login Success","script":"..."}
-- extract field "script"
local script = raw:match('"script"%s*:%s*"(.*)"[^"]*}%s*$')
if not script then
    -- coba pattern yang lebih relaxed
    script = raw:match('"script"%s*:%s*"(.+)')
    if script then
        -- trim trailing "} dan whitespace
        script = script:match('^(.-)\\?"?%s*}?%s*$') or script
        -- remove trailing quote+brace
        script = script:gsub('"[^"]*}%s*$', '')
    end
end

if not script then
    print("Gagal parse JSON, coba raw loadstring...")
    script = raw
end

-- unescape JSON
script = script:gsub('\\"', '"')
script = script:gsub('\\r\\n', '\n')
script = script:gsub('\\r', '\n')
script = script:gsub('\\n', '\n')
script = script:gsub('\\t', '\t')
script = script:gsub('\\/', '/')
script = script:gsub('\\\\', '\\')

print("Script len after unescape: " .. #script)
print("Preview: " .. script:sub(1, 200))

-- execute
local fn, err = loadstring(script)
if not fn then
    error("loadstring error: " .. tostring(err))
end

print("Executing payload...")
fn()
