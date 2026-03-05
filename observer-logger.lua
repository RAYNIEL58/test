--[[
  OBSERVER / LOGGER SCRIPT
  Inject this to log what the game (or other scripts) are doing.
  Prints to the executor console: RemoteEvent/RemoteFunction calls and arguments.
]]

-- Get the first script that appears BEFORE this observer (e.g. the one you had before injecting).
local function getFirstScriptBeforeObserver()
	local selfScript = (type(script) == "userdata" and script) or (getfenv(1).script)
	if not selfScript or not selfScript.Parent then return nil end
	local parent = selfScript.Parent
	local siblings = parent:GetChildren()
	local selfIndex = nil
	for i, child in ipairs(siblings) do
		if child == selfScript then selfIndex = i break end
	end
	if not selfIndex or selfIndex <= 1 then return nil end
	-- Find the last script (Script/LocalScript/ModuleScript) that comes before us
	local scriptClasses = { Script = true, LocalScript = true, ModuleScript = true }
	for i = selfIndex - 1, 1, -1 do
		local s = siblings[i]
		if s and scriptClasses[s.ClassName] then
			return s
		end
	end
	return nil
end

local FirstScriptBeforeObserver = getFirstScriptBeforeObserver()
if FirstScriptBeforeObserver then
	print("[Observer] First script before this one:", FirstScriptBeforeObserver:GetFullName())
else
	print("[Observer] No script found before this one (standalone or first in parent).")
end

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
