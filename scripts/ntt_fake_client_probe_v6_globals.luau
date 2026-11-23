-- NTT Hub offline fake Roblox probe (Lune). NEVER connects to the network.
-- Starting point: run in INTERCEPT_ONLY mode. PROBE_PAYLOAD is experimental.
-- IMPORTANT: run even this restricted script in a disposable OS/container VM
-- with network disabled and no Roblox login credentials or personal files.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local PROBE_PAYLOAD = true  -- change to true only in a fully isolated offline VM
local LOADER_FILE = "evidence/ntt_loader.lua"
local PAYLOAD_FILE = "evidence/ntt_payload_obf.lua"
local LINK_FILE = "evidence/ntt_server/link.lua" -- optional offline snapshot

local PAYLOAD_URL = "https://raw.githubusercontent.com/NTTTTTTTT/upload/refs/heads/main/content/52c3bd79bdd9407aab6a5e0fad32b3d0_obf.lua"
local LINK_URL = "https://raw.githubusercontent.com/NTT-HUB/Script/refs/heads/main/link"

local counters = { http = 0, loads = 0, requests = 0, globals = {} }
local function log(kind, ...)
    print("[FAKE_CLIENT]", kind, ...)
end

local env = {}
local function forbid(moduleName)
    error("Blocked privileged operation: " .. tostring(moduleName), 2)
end

local function mockedRequest(options)
    counters.requests += 1
    local url = if type(options) == "table" then options.Url or options.URL or options.url else tostring(options)
    log("HTTP_REQUEST_BLOCKED", tostring(url), if type(options) == "table" then tostring(options.Method or options.method or "GET") else "?")
    -- No real HTTP request or credentials are sent. A refused response prevents
    -- accidental credential submission and avoids inventing server responses.
    return { StatusCode = 403, Success = false, Body = "", Headers = {} }
end

local fakePlayer = {
    Name = "OfflineDummy",
    UserId = 0,
    Idled = {},
    Kick = function(_, why) log("KICK", tostring(why)) end,
}
local fakePlayers = { LocalPlayer = fakePlayer }

local fakeGame = {
    PlaceId = 0,
    GameId = 0,
    JobId = "offline-lab",
    IsLoaded = function() return true end,
    GetService = function(_, name)
        log("GET_SERVICE", tostring(name))
        if name == "Players" then return fakePlayers end
        return setmetatable({ Name = tostring(name) }, {
            __index = function(_, key)
                log("UNSUPPORTED_SERVICE_PROPERTY", tostring(name), tostring(key))
                return nil
            end,
        })
    end,
    HttpGet = function(_, url, useCache)
        counters.http += 1
        log("HTTP_GET_INTERCEPTED", tostring(url), "cache=", tostring(useCache))
        if url == PAYLOAD_URL then
            return fs.readFile(PAYLOAD_FILE)
        elseif url == LINK_URL and fs.isFile(LINK_FILE) then
            return fs.readFile(LINK_FILE)
        end
        -- Never fetch unrecognized URLs; do not imitate a successful server.
        error("Unrecognized or unavailable offline URL: " .. tostring(url), 2)
    end,
}

-- The guest gets no access to Lune's fs/net/process libraries.
-- Luau standard math/string/table functions are injected by the load option.
env.game = fakeGame
env._G = env
env.string = string

-- NTT_STD_GLOBALS_V3
local function nttCopyLibrary(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

env.string = nttCopyLibrary(string)
env.math = nttCopyLibrary(math)
env.table = nttCopyLibrary(table)
env.bit32 = nttCopyLibrary(bit32)
env.coroutine = nttCopyLibrary(coroutine)
env.utf8 = nttCopyLibrary(utf8)

if buffer ~= nil then
    env.buffer = nttCopyLibrary(buffer)
end

-- 파일 실행이나 프로세스 실행 기능은 노출하지 않음
env.os = {
    clock = os.clock,
    time = os.time,
    date = os.date,
    difftime = os.difftime,
}

local nttBaseFunctions = {
    assert = assert,
    error = error,
    type = type,
    typeof = typeof,
    tonumber = tonumber,
    tostring = tostring,
    pairs = pairs,
    ipairs = ipairs,
    next = next,
    select = select,
    pcall = pcall,
    xpcall = xpcall,
    rawget = rawget,
    rawset = rawset,
    rawequal = rawequal,
    setmetatable = setmetatable,
    getmetatable = getmetatable,
    unpack = unpack or table.unpack,
}

for key, value in pairs(nttBaseFunctions) do
    env[key] = value
end

-- Lune 모듈 접근 차단
env.require = function(...)
    error("OFFLINE_REQUIRE_BLOCKED", 2)
end

assert(type(env.string.char) == "function")
assert(type(env.math.floor) == "function")
assert(type(env.table.insert) == "function")
assert(type(env.bit32.bxor) == "function")
assert(type(env.coroutine.create) == "function")
assert(type(env.utf8.len) == "function")
assert(type(env.os.clock) == "function")

print("[FAKE_CLIENT] SELF_TEST passed standard globals")
-- END_NTT_STD_GLOBALS_V3

env.print = function(...) log("GUEST_PRINT", ...) end
env.warn = function(...) log("GUEST_WARN", ...) end
env.require = function(...) forbid("require") end
env.getgenv = function() return env end
env.getrenv = function() return env end
env.getfenv = function() return env end
env.setfenv = function(...) log("SETFENV_REQUEST", ...); return nil end
env.request = mockedRequest
env.http_request = mockedRequest
env.syn = { request = mockedRequest }
env.fluxus = { request = mockedRequest }
env.getconnections = function() log("GET_CONNECTIONS"); return {} end
env.identifyexecutor = function() return "offline-mock" end
env.getexecutorname = function() return "offline-mock" end
env.get_hwid = function() log("HWID_REQUEST"); return "OFFLINE-DO-NOT-USE" end
env.isfunctionhooked = function() return false end


-- V4: separate compile/runtime error tracing.
local function traceError(stage, err)
    log("ERROR_STAGE", stage)
    log("ERROR_TYPE", type(err))
    log("ERROR_VALUE", tostring(err))

    if type(debug) == "table" then
        if type(debug.traceback) == "function" then
            local ok, traceback = pcall(
                debug.traceback,
                tostring(err),
                2
            )
            if ok then
                log("ERROR_TRACEBACK", traceback)
            end
        end

        if type(debug.info) == "function" then
            for level = 2, 20 do
                local ok, source, line, name = pcall(
                    debug.info,
                    level,
                    "sln"
                )
                if not ok or source == nil then
                    break
                end

                log(
                    "ERROR_FRAME",
                    level,
                    tostring(source),
                    tostring(line),
                    tostring(name)
                )
            end
        end
    end

    return err
end

-- Observe explicit error() calls made through the guest environment.
env.error = function(message, level)
    local msg = tostring(message)

    log("GUEST_ERROR_CALLED", msg, "level=", tostring(level))

    if msg == "0:18:0" then
        log("FINAL_ERROR_ORIGIN", "captured before raising")

        if debug and type(debug.traceback) == "function" then
            log(
                "FINAL_ERROR_CALLSITE",
                debug.traceback("NTT final error call", 2)
            )
        end

        if debug and type(debug.info) == "function" then
            for depth = 2, 30 do
                local ok, source, line, name =
                    pcall(debug.info, depth, "sln")

                if not ok or source == nil then
                    break
                end

                log(
                    "FINAL_ERROR_FRAME",
                    depth,
                    tostring(source),
                    tostring(line),
                    tostring(name)
                )
            end
        end
    end

    return error(message, level)
end

env.loadstring = function(source)
    counters.loads += 1
    log("LOADSTRING_INTERCEPTED", "bytes=", #source)

    if not PROBE_PAYLOAD then
        return function()
            log("PAYLOAD_EXECUTION_SKIPPED")
        end
    end

    local compiled, result = xpcall(function()
        return luau.load(source, {
            debugName = "ntt_nested_payload",
            environment = env,
            injectGlobals = false,
        })
    end, function(err)
        return traceError("NESTED_COMPILE", err)
    end)

    if not compiled then
        log("LOADSTRING_COMPILE_ERROR", tostring(result))
        return function() end
    end

    log("NESTED_COMPILE_OK")

    return function(...)
        local args = table.pack(...)

        log("NESTED_RUNTIME_BEGIN")

        local ran, value = xpcall(function()
            return result(table.unpack(args, 1, args.n))
        end, function(err)
            return traceError("NESTED_RUNTIME", err)
        end)

        if not ran then
            log("NESTED_RUNTIME_HALTED", tostring(value))
            error(value, 0)
        end

        log("NESTED_RUNTIME_COMPLETED")
        return value
    end
end

-- Test the actual guest environment, not only the host-side env table.

-- V6: record missing guest globals without supplying fake values.
local missingGlobals = {}
local missingCount = 0

setmetatable(env, {
    __index = function(_, key)
        local name = tostring(key)

        if not missingGlobals[name] then
            missingGlobals[name] = true
            missingCount += 1

            if missingCount <= 80 then
                log("MISSING_GLOBAL_READ", name)
            end
        end

        return nil
    end,
})

log("GLOBAL_TRACE_ENABLED")

local selfOk, selfErr = xpcall(function()
    local test = luau.load([[
        assert(getfenv(1) == _G, "getfenv mismatch")
        assert(type(string.char) == "function")
        assert(type(math.floor) == "function")
        assert(type(table.insert) == "function")
        assert(type(bit32.bxor) == "function")
    ]], {
        debugName = "offline_guest_selftest",
        environment = env,
        injectGlobals = false,
    })

    test()
end, function(err)
    return traceError("GUEST_SELF_TEST", err)
end)

log(
    "GUEST_SELF_TEST",
    if selfOk then "passed" else "failed",
    if selfOk then "" else tostring(selfErr)
)

local ok, err

if selfOk then
    ok, err = xpcall(function()
        local source = fs.readFile(LOADER_FILE)

        local chunk = luau.load(source, {
            debugName = "ntt_loader_offline",
            environment = env,
            injectGlobals = false,
        })

        log("LOADER_RUNTIME_BEGIN")
        chunk()
        log("LOADER_RUNTIME_COMPLETED")
    end, function(e)
        return traceError("LOADER_RUNTIME", e)
    end)
else
    ok, err = false, selfErr
end

log(
    "RESULT",
    if ok then "completed" else "halted",
    if ok then "" else tostring(err)
)

log(
    "SUMMARY",
    "HttpGet=", counters.http,
    "loadstring=", counters.loads,
    "requests=", counters.requests
)
