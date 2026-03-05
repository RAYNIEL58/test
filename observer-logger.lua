--[[
  OBSERVER / LOGGER SCRIPT
  Inject this to log what the game (or other scripts) are doing.
  Prints to the executor console: RemoteEvent/RemoteFunction calls and arguments.
]]

print("[Observer] Logger loaded. Watching FireServer / InvokeServer...")

local function safeToString(v)
    local ok, result = pcall(function()
        if type(v) == "userdata" or type(v) == "vector" or type(v) == "Instance" then
            return tostring(v)
        end
        if type(v) == "table" then
            return "table#" .. tostring(v):match("%x+") or "table"
        end
        return tostring(v)
    end)
    return ok and result or "<error>"
end

local function formatArgs(...)
    local args = {...}
    local parts = {}
    for i, a in ipairs(args) do
        if type(a) == "string" then
            table.insert(parts, ("%q"):format(a))
        else
            table.insert(parts, safeToString(a))
        end
    end
    return table.concat(parts, ", ")
end

-- Hook all :FireServer() and :InvokeServer() via __namecall
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(remote, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local name = (typeof(remote) == "Instance" and remote.Name) or tostring(remote)
        local path = (typeof(remote) == "Instance" and remote:GetFullName()) or name
        local argsStr = formatArgs(...)
        if method == "FireServer" then
            print(string.format("[FireServer] %s | %s", path, argsStr))
        else
            local ret = oldNamecall(remote, ...)
            print(string.format("[InvokeServer] %s | args: %s | return: %s", path, argsStr, safeToString(ret)))
            return ret
        end
    end
    return oldNamecall(remote, ...)
end)

-- Optional: log when Remotes are created (so you know what exists)
if game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") or game:GetService("ReplicatedStorage"):FindFirstChild("Events") then
    print("[Observer] ReplicatedStorage has Remotes/Events folder. All calls will be logged above.")
end

print("[Observer] Ready. Use the other script / game — output will appear here.")
