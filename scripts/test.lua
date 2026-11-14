-- usage: lua5.1 scripts/test.lua <file.test.lua>...
-- WoW 와 같은 Lua 5.1 에서 외부 라이브러리 없이 돈다 → 로컬·CI 에 인터프리터 하나만 있으면 된다.

local failures, passed = {}, 0

local function serialize(v, depth)
    depth = depth or 0
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) ~= "table" then return tostring(v) end
    if depth > 3 then return "{...}" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = "[" .. serialize(k, depth + 1) .. "]=" .. serialize(v[k], depth + 1)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function deep_equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not deep_equal(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function new_env(file)
    local env = setmetatable({}, { __index = _G })
    local scope = {}

    function env.describe(name, fn)
        scope[#scope + 1] = name
        fn()
        scope[#scope] = nil
    end

    function env.it(name, fn)
        env.__ran = (env.__ran or 0) + 1
        local full = table.concat(scope, " > ") .. " > " .. name
        local ok, err = xpcall(fn, debug.traceback)
        if ok then
            passed = passed + 1
        else
            failures[#failures + 1] = file .. ": " .. full .. "\n    " .. tostring(err):gsub("\n", "\n    ")
        end
    end

    function env.eq(actual, expected, msg)
        if not deep_equal(actual, expected) then
            error((msg and msg .. "\n" or "") .. "expected: " .. serialize(expected) .. "\n  actual: " .. serialize(actual), 2)
        end
    end

    function env.raises(fn, pattern)
        local ok, err = pcall(fn)
        if ok then error("expected an error, got none", 2) end
        if pattern and not tostring(err):find(pattern) then
            error("error did not match " .. serialize(pattern) .. ": " .. tostring(err), 2)
        end
    end

    -- 애드온 파일은 `local addonName, ns = ...` 로 시작한다 → TOC 로드와 같은 인자로 실행한다.
    -- 테스트 파일과 같은 환경에서 실행해, 테스트가 넣은 WoW API 대역을 소스가 전역으로 본다.
    function env.load_source(path, ns)
        local chunk, err = loadfile(path)
        if not chunk then error(err, 2) end
        setfenv(chunk, env)
        return chunk("LorePin", ns)
    end

    return env
end

for _, file in ipairs(arg) do
    local chunk, err = loadfile(file)
    if not chunk then
        failures[#failures + 1] = file .. ": load\n    " .. tostring(err)
    else
        local env = new_env(file)
        setfenv(chunk, env)
        local ok, runErr = xpcall(chunk, debug.traceback)
        if not ok then
            failures[#failures + 1] = file .. ": top level\n    " .. tostring(runErr):gsub("\n", "\n    ")
        elseif not env.__ran then
            -- 오타·빈 describe 로 테스트가 하나도 안 돌면 통과로 보이지 않게 한다.
            failures[#failures + 1] = file .. ": no tests ran"
        end
    end
end

for _, f in ipairs(failures) do
    io.stderr:write("FAIL " .. f .. "\n")
end
print(string.format("테스트: %d passed, %d failed (%d files)", passed, #failures, #arg))
os.exit(#failures == 0 and 0 or 1)
