--[[
==============================================================================
  OBSERVER – watch the SCRIPT you paste in the executor (not the game)
==============================================================================

  You want to observe: the FIRST SCRIPT you input (the one you paste/run).

  INJECT ORDER – two ways:

  A) RECOMMENDED – so we see every FireServer/InvokeServer from your script:
     1) Run THIS observer first.
     2) Then run/paste the script you want to observe.
     → All Remotes, Tweens, Teleport, Kick from YOUR script get logged + Discord.

  B) You already ran your script first:
     1) Before observer, set:  _G.FIRST_SCRIPT_SOURCE = "paste your script here"
        OR save your script as first.lua in the executor folder.
     2) Run this observer.
     → We send that script’s code to Discord. We can’t see past calls, but we
       will log any future calls (e.g. if your script connected to events).
==============================================================================
]]

local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1479152924402647231/rtgjUt8LjlCdNjhIAdJGY9xJGDffQuH37d3kdy9DOPTcYycCW9Cd1J-6lYafDFFDP6-K"

local actionLog = {}
local MAX_LOG = 20

local function safeStr(v)
	local ok, s = pcall(function()
		if type(v) == "userdata" or type(v) == "vector" then return tostring(v) end
		if type(v) == "Instance" then return v:GetFullName() end
		if type(v) == "table" then return "table" end
		return tostring(v)
	end)
	return ok and s or "?"
end

local function formatArgs(...)
	local t = {...}
	local parts = {}
	for i = 1, math.min(#t, 8) do
		local v = t[i]
		if type(v) == "string" then
			table.insert(parts, ("%q"):format(v:sub(1, 80)))
		else
			table.insert(parts, safeStr(v))
		end
	end
	if #t > 8 then table.insert(parts, "...") end
	return table.concat(parts, ", ")
end

local function logAction(msg)
	table.insert(actionLog, msg)
	if #actionLog > MAX_LOG then table.remove(actionLog, 1) end
	print("[OBSERVER] " .. msg)
end

local function sendToDiscord(content, useEmbed)
	if type(content) ~= "string" or #content == 0 then return end
	pcall(function()
		local payload
		if useEmbed and #content > 500 then
			local desc = content:sub(1, 3900)
			if #content > 3900 then desc = desc .. "\n...(truncated)" end
			payload = { content = "**First script you wanted to observe** (source below)", embeds = { { title = "Source", description = ("```lua\n%s\n```"):format(desc) } } }
		else
			payload = { content = content:sub(1, 1990) }
		end
		local body
		if game and game:GetService then
			body = game:GetService("HttpService"):JSONEncode(payload)
			game:GetService("HttpService"):PostAsync(DISCORD_WEBHOOK_URL, body)
		elseif type(request) == "function" then
			local function esc(s) return ("%q"):format(tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")) end
			if payload.embeds and payload.embeds[1] then
				local e = payload.embeds[1]
				body = ("{\"content\":%s,\"embeds\":[{\"title\":%s,\"description\":%s}]}"):format(esc(payload.content), esc(e.title), esc(e.description or ""))
			else
				body = ("{\"content\":%s}"):format(esc(payload.content))
			end
			request({ Url = DISCORD_WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
		end
	end)
end

-- Build a short summary of recent actions for Discord
local function recentActionsSummary()
	local s = {}
	for i = math.max(1, #actionLog - 9), #actionLog do
		table.insert(s, actionLog[i] or "")
	end
	return table.concat(s, "\n")
end

-- Try to get the FIRST SCRIPT you input (before observer) and send to Discord
local function sendFirstScriptToDiscord()
	local source, label = nil, nil
	-- From _G (set before running observer)
	local fromG = _G.FIRST_SCRIPT_SOURCE or _G.__FIRST_SCRIPT_SOURCE
	if type(fromG) == "string" and #fromG > 0 then
		source, label = fromG, "From _G.FIRST_SCRIPT_SOURCE (script you wanted to observe)"
	end
	-- From readfile (e.g. first.lua in executor folder)
	if (not source) and type(readfile) == "function" then
		for _, name in ipairs({ "first.lua", "first_script.lua" }) do
			local ok, content = pcall(readfile, name)
			if ok and type(content) == "string" and #content > 0 then
				source, label = content, ("From readfile(%q)"):format(name)
				break
			end
		end
	end
	if source and #source > 0 then
		logAction("Sending first script source to Discord: " .. (label or "?"))
		sendToDiscord(source, true)
	end
end

local mt = getrawmetatable(game)
setreadonly(mt, false)
local originalNamecall = mt.__namecall

mt.__namecall = newcclosure(function(self, ...)
	local method = getnamecallmethod()
	local args = {...}

	-- Remotes: log name, args, and send to Discord
	if method == "FireServer" then
		local name = (type(self) == "userdata" and self.Name) or tostring(self)
		local path = type(self) == "userdata" and self.GetFullName and self:GetFullName() or name
		local msg = ("[FireServer] %s | %s"):format(path, formatArgs(...))
		logAction("FireServer: " .. name)
		sendToDiscord("**FireServer**\n`" .. path .. "`\nArgs: " .. formatArgs(...))
		return originalNamecall(self, ...)
	end

	if method == "InvokeServer" then
		local name = (type(self) == "userdata" and self.Name) or tostring(self)
		local path = type(self) == "userdata" and self.GetFullName and self:GetFullName() or name
		local ret = originalNamecall(self, ...)
		local msg = ("[InvokeServer] %s | args: %s | return: %s"):format(path, formatArgs(...), safeStr(ret))
		logAction("InvokeServer: " .. name)
		sendToDiscord("**InvokeServer**\n`" .. path .. "`\nArgs: " .. formatArgs(...) .. "\nReturn: " .. safeStr(ret))
		return ret
	end

	-- TweenService:Create (movement / bypass)
	if method == "Create" and tostring(self) == "TweenService" then
		logAction("TweenService:Create (possible movement tween)")
		sendToDiscord("**Tween** created (TweenService:Create)")
		return originalNamecall(self, ...)
	end

	-- Teleport
	if method == "SetPrimaryPartCFrame" then
		logAction("SetPrimaryPartCFrame (teleport)")
		sendToDiscord("**Teleport** via SetPrimaryPartCFrame\nRecent:\n" .. recentActionsSummary())
		return originalNamecall(self, ...)
	end

	-- Kick
	if method == "Kick" then
		local msg = "**WARNING: Kick** called by " .. tostring(self.Name or self)
		logAction("Kick called!")
		sendToDiscord(msg .. "\nRecent:\n" .. recentActionsSummary())
		return originalNamecall(self, ...)
	end

	-- GetService – see which services the script uses
	if method == "GetService" then
		local svc = type(args[1]) == "string" and args[1] or safeStr(args[1])
		if svc and svc ~= "?" then
			logAction("GetService: " .. svc)
		end
		return originalNamecall(self, ...)
	end

	-- Instance.new – log when creating important classes
	if method == "new" and tostring(self) == "Instance" then
		local className = type(args[1]) == "string" and args[1] or ""
		if className == "RemoteEvent" or className == "RemoteFunction" or className == "BindableEvent" or className == "BindableFunction" then
			logAction("Instance.new: " .. className)
		end
		return originalNamecall(self, ...)
	end

	-- :Connect on Remotes (so you see when script listens to events)
	if method == "Connect" or method == "connect" then
		local parent = type(self) == "userdata" and self.GetFullName and self:GetFullName()
		if parent and (parent:find("RemoteEvent") or parent:find("RemoteFunction") or parent:find("Bindable")) then
			logAction("Connect: " .. tostring(parent))
		end
		return originalNamecall(self, ...)
	end

	-- Finding Remotes (script getting a remote reference)
	if method == "FindFirstChild" or method == "WaitForChild" then
		local childName = type(args[1]) == "string" and args[1] or ""
		local parent = type(self) == "userdata" and self.GetFullName and self:GetFullName()
		if parent and childName and (childName:lower():find("remote") or childName:lower():find("event") or childName:lower():find("invoke")) then
			logAction(("Get child %q from %s"):format(childName, parent))
		end
		return originalNamecall(self, ...)
	end

	return originalNamecall(self, ...)
end)

setreadonly(mt, true)

-- If you ran your script first and set _G.FIRST_SCRIPT_SOURCE or first.lua, we send it to Discord now
sendFirstScriptToDiscord()

logAction("Observer loaded. Watching the script you paste – FireServer, InvokeServer, Tween, Teleport, Kick will be logged + Discord.")
sendToDiscord("**Observer** is active. Watching YOUR script (the one you paste). Remotes/Tween/Teleport/Kick will appear here.")
