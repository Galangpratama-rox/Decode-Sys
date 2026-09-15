local raw = readfile("syshub_intercept_2.lua")
print("raw len: "..#raw)

local s = raw:find('"script":"', 1, true)
if not s then error("field script tidak ditemukan") end

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
            -- \u{XXXX} Luau unicode — biarkan as-is
            if content:sub(i+2, i+2) == '{' then
                local close = content:find('}', i+3, true)
                if close then
                    table.insert(result, content:sub(i, close))
                    i = close + 1
                else
                    table.insert(result, '\\u'); i = i + 2
                end
            else
                -- \uXXXX standard
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

local script = table.concat(result)
print("script len: "..#script)
print("preview: "..script:sub(1, 100))

local fn, err = loadstring(script)
if not fn then
    local linenum = tonumber(err:match(":(%d+):"))
    if linenum then
        local line = 0
        for l in script:gmatch("[^\n]+") do
            line = line + 1
            if line >= linenum-1 and line <= linenum+1 then
                print("line "..line..": "..l:sub(1,150))
            end
        end
    end
    error("loadstring: "..tostring(err))
end

print("Executing...")
fn()
