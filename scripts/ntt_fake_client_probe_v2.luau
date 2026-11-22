-- NTT Hub offline fake Roblox probe (Lune). NEVER connects to the network.
-- Starting point: run in INTERCEPT_ONLY mode. PROBE_PAYLOAD is experimental.
-- IMPORTANT: run even this restricted script in a disposable OS/container VM
-- with network disabled and no Roblox login credentials or personal files.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local PROBE_PAYLOAD = false  -- change to true only in a fully isolated offline VM
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

-- Explicitly expose ONLY Lua/Luau pure standard libraries and primitives.
-- In this mock, getfenv(1) returns `env`; without these fields, the original
-- NTT payload crashes at startup on getfenv(1).string.char.
env.string = string
env.table = table
env.math = math
env.bit32 = bit32
env.utf8 = utf8
env.coroutine = coroutine
env.buffer = buffer

env.assert = assert
env.error = error
env.type = type
env.typeof = typeof
env.tostring = tostring
env.tonumber = tonumber
env.select = select
env.pairs = pairs
env.ipairs = ipairs
env.next = next
env.unpack = unpack
env.pcall = pcall
env.xpcall = xpcall
env.setmetatable = setmetatable
env.getmetatable = getmetatable
env.rawget = rawget
env.rawset = rawset
env.rawequal = rawequal

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

env.loadstring = function(source)
    counters.loads += 1
    log("LOADSTRING_INTERCEPTED", "bytes=", #source)
    if not PROBE_PAYLOAD then
        return function() log("PAYLOAD_EXECUTION_SKIPPED") end
    end
    local ok, result = pcall(function()
        return luau.load(source, {
            debugName = "ntt_nested_payload",
            environment = env,
            injectGlobals = true,
        })
    end)
    if not ok then
        log("LOADSTRING_COMPILE_ERROR", tostring(result))
        return function() end
    end
    return result
end

local ok, err = pcall(function()
    local source = fs.readFile(LOADER_FILE)
    local chunk = luau.load(source, {
        debugName = "ntt_loader_offline",
        environment = env,
        injectGlobals = true,
    })
    chunk()
end)
log("RESULT", if ok then "completed" else "halted", if ok then "" else tostring(err))
log("SUMMARY", "HttpGet=", counters.http, "loadstring=", counters.loads, "requests=", counters.requests)
