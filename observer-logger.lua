--[[
==============================================================================
  OBSERVER – watch the script you paste in the executor
==============================================================================

  Why you might get banned:
  (1) This observer hooks game's metatable (getrawmetatable, __namecall).
      Anti-cheat can detect that and ban.
  (2) The script you run might do bannable things (teleport, spam remotes, etc.).
      The observer only LOGS what happens – it doesn't stop the game from seeing it.

  This version keeps only essential hooks (FireServer, InvokeServer, Tween,
  Teleport, Kick) to reduce detection. No extra hooks (GetService, Connect, etc.).

  INJECT: Run observer first, then the script you want to observe.
  Or set _G.FIRST_SCRIPT_SOURCE / readfile("first.lua") then run observer.
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
			payload = { content = "**First script** (source below)", embeds = { { title = "Source", description = ("```lua\n%s\n```"):format(desc) } } }
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

local function recentActionsSummary()
	local s = {}
	for i = math.max(1, #actionLog - 9), #actionLog do
		table.insert(s, actionLog[i] or "")
	end
	return table.concat(s, "\n")
end

local function sendFirstScriptToDiscord()
	local source, label = nil, nil
	local fromG = _G.FIRST_SCRIPT_SOURCE or _G.__FIRST_SCRIPT_SOURCE
	if type(fromG) == "string" and #fromG > 0 then
		source, label = fromG, "From _G.FIRST_SCRIPT_SOURCE"
	end
	if (not source) and type(readfile) == "function" then
		for _, name in ipairs({ "first.lua", "first_script.lua" }) do
			local ok, content = pcall(readfile, name)
			if ok and type(content) == "string" and #content > 0 then
				source, label = content, ("readfile(%q)"):format(name)
				break
			end
		end
	end
	if source and #source > 0 then
		logAction("Sending first script to Discord: " .. (label or "?"))
		sendToDiscord(source, true)
	end
end

local mt = getrawmetatable(game)
setreadonly(mt, false)
local originalNamecall = mt.__namecall

-- Only hook what we need: Remotes, Tween, Teleport, Kick. No GetService/Connect/FindFirstChild.
mt.__namecall = newcclosure(function(self, ...)
	local method = getnamecallmethod()
	local args = {...}

	if method == "FireServer" then
		local name = (type(self) == "userdata" and self.Name) or tostring(self)
		local path = type(self) == "userdata" and self.GetFullName and self:GetFullName() or name
		logAction("FireServer: " .. name)
		sendToDiscord("**FireServer**\n`" .. path .. "`\nArgs: " .. formatArgs(...))
		return originalNamecall(self, ...)
	end

	if method == "InvokeServer" then
		local name = (type(self) == "userdata" and self.Name) or tostring(self)
		local path = type(self) == "userdata" and self.GetFullName and self:GetFullName() or name
		local ret = originalNamecall(self, ...)
		logAction("InvokeServer: " .. name)
		sendToDiscord("**InvokeServer**\n`" .. path .. "`\nArgs: " .. formatArgs(...) .. "\nReturn: " .. safeStr(ret))
		return ret
	end

	if method == "Create" and tostring(self) == "TweenService" then
		logAction("TweenService:Create")
		sendToDiscord("**Tween** created (TweenService:Create)")
		return originalNamecall(self, ...)
	end

	if method == "SetPrimaryPartCFrame" then
		logAction("SetPrimaryPartCFrame (teleport)")
		sendToDiscord("**Teleport** SetPrimaryPartCFrame\nRecent:\n" .. recentActionsSummary())
		return originalNamecall(self, ...)
	end

	if method == "Kick" then
		logAction("Kick called!")
		sendToDiscord("**Kick** called by " .. tostring(self.Name or self) .. "\nRecent:\n" .. recentActionsSummary())
		return originalNamecall(self, ...)
	end

	return originalNamecall(self, ...)
end)

setreadonly(mt, true)

sendFirstScriptToDiscord()

logAction("Observer loaded. Essential hooks only (FireServer, InvokeServer, Tween, Teleport, Kick).")
sendToDiscord("**Observer** active. Logging Remotes / Tween / Teleport / Kick to this webhook.")
