--[[
==============================================================================
  REALTIME OBSERVER – see what the script is doing (prints, toggles, remotes, etc.)
==============================================================================

  Use: Run THIS observer first, then run the OTHER script (e.g. the one from
  online). Your own script (e.g. archive/test.lua) is just your sample – the
  observer watches whatever script you run after it.

  Logs to your Discord webhook:
  - Console errors (e.g. "attempt to call a nil value", animation failed)
  - Script print/warn/error (e.g. "Auto farm activated", "Teleporting to player")
  - FireServer / InvokeServer (remotes + args)
  - Tween (dash) + Teleport (position)
  - HTTP calls, Kick, BindableEvent

  Run observer FIRST → then run the script you want to observe.
==============================================================================
]]

-- Your Discord webhook – observer sends debug logs here. Don't share or commit this URL.
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1479433171673022674/f3h7jy2fDUPElS5KUz_CDHwhUtYOx_hL3mh_t_x2CGqRmIETBJ8sCMY4eXbqWwXCkGMo"

local actionLog = {}
local MAX_LOG = 20

-- Try to send a message to Discord (works with injectors: request, http_request, HttpService)
local function trySendToDiscordRaw(content)
	if type(content) ~= "string" or #content == 0 then return false end
	local payload = ("{\"content\":%s}"):format(
		("%q"):format(tostring(content):sub(1, 1990):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"))
	)
	local ok = pcall(function()
		if game and type(game.GetService) == "function" then
			local HttpService = game:GetService("HttpService")
			if HttpService and HttpService.PostAsync then
				local body = HttpService:JSONEncode({ content = content:sub(1, 1990) })
				HttpService:PostAsync(DISCORD_WEBHOOK_URL, body)
				return
			end
		end
	end)
	if ok then return true end
	ok = pcall(function()
		local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
		if type(req) == "function" then
			req({ Url = DISCORD_WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
			return
		end
	end)
	return ok
end

-- Ping Discord immediately so you know the script ran (works with injectors)
trySendToDiscordRaw("**Observer** injecting... If you see this, the script started. Setting up hooks...")

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

-- Format CFrame or Vector3 for Discord (so you see exact teleport/dash target)
local function formatCFrameOrVector(v)
	if type(v) == "userdata" then
		local ok, x, y, z = pcall(function()
			if v.X and v.Y and v.Z then return v.X, v.Y, v.Z end -- Vector3
			if v.Position then local p = v.Position return p.X, p.Y, p.Z end -- CFrame
			return nil, nil, nil
		end)
		if ok and x then return ("%.2f, %.2f, %.2f"):format(x, y, z) end
	end
	return safeStr(v)
end

local function formatTweenGoals(propTable)
	if type(propTable) ~= "table" then return "" end
	local parts = {}
	if propTable.CFrame then
		table.insert(parts, "CFrame → " .. formatCFrameOrVector(propTable.CFrame))
	end
	if propTable.Position then
		table.insert(parts, "Position → " .. formatCFrameOrVector(propTable.Position))
	end
	for k, v in pairs(propTable) do
		if k ~= "CFrame" and k ~= "Position" and type(v) == "userdata" and (v.X or v.Position) then
			table.insert(parts, tostring(k) .. " → " .. formatCFrameOrVector(v))
		end
	end
	return #parts > 0 and table.concat(parts, " | ") or ""
end

local function logAction(msg)
	table.insert(actionLog, msg)
	if #actionLog > MAX_LOG then table.remove(actionLog, 1) end
	print("[OBSERVER] " .. msg)
end

local function sendToDiscord(content, useEmbed)
	if type(content) ~= "string" or #content == 0 then return end
	local msg = content:sub(1, 1990)
	local sent = pcall(function()
		if game and game:GetService then
			local HttpService = game:GetService("HttpService")
			if HttpService and HttpService.JSONEncode and HttpService.PostAsync then
				local payload = (useEmbed and #content > 500) and { content = "**First script** (source below)", embeds = { { title = "Source", description = ("```lua\n%s\n```"):format(content:sub(1, 3900)) } } } or { content = msg }
				local body = HttpService:JSONEncode(payload)
				HttpService:PostAsync(DISCORD_WEBHOOK_URL, body)
				return
			end
		end
		-- Fallback for injectors (request, http_request, syn.request, etc.)
		local payload = ("{\"content\":%s}"):format(("%q"):format(msg:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")))
		local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
		if type(req) == "function" then
			req({ Url = DISCORD_WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
		end
	end)
	if not sent then trySendToDiscordRaw(msg) end
end

local function recentActionsSummary()
	local s = {}
	for i = math.max(1, #actionLog - 9), #actionLog do
		table.insert(s, actionLog[i] or "")
	end
	return table.concat(s, "\n")
end

-- Format ... into one string (for print/warn/error)
local function formatPrintArgs(...)
	local n = select("#", ...)
	if n == 0 then return "" end
	local parts = {}
	for i = 1, n do
		parts[i] = tostring(select(i, ...))
	end
	return table.concat(parts, " ")
end

-- Throttle: batch script prints so we don't flood Discord (rate limit ~30/min)
local PRINT_THROTTLE_SEC = 1.2
local printBuffer = {}
local lastPrintSend = 0

local function flushPrintBuffer()
	if #printBuffer == 0 then return end
	local text = table.concat(printBuffer, "\n")
	printBuffer = {}
	lastPrintSend = tick()
	sendToDiscord("**Script said (print)**\n" .. text:sub(1, 1900))
end

local function sendScriptPrint(label, ...)
	local msg = formatPrintArgs(...)
	if msg == "" then return end
	-- Skip our own observer messages
	if msg:find("^%[OBSERVER%]") then return end
	logAction("Script: " .. msg:sub(1, 60))
	table.insert(printBuffer, msg)
	if tick() - lastPrintSend >= PRINT_THROTTLE_SEC then
		flushPrintBuffer()
	end
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

-- Metatable hook (skipped if injector doesn't provide getrawmetatable/newcclosure/getnamecallmethod)
local metatableHooked = false
pcall(function()
	if type(getrawmetatable) ~= "function" or type(setreadonly) ~= "function" or type(newcclosure) ~= "function" or type(getnamecallmethod) ~= "function" then return end
	if not game then return end
	local mt = getrawmetatable(game)
	if not mt or not rawget(mt, "__namecall") then return end
	setreadonly(mt, false)
	local originalNamecall = mt.__namecall
	mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		local args = {...}

	if method == "Fire" then
		local className = type(self) == "userdata" and self.ClassName or ""
		if className == "BindableEvent" or className == "BindableFunction" then
			local name = (type(self) == "userdata" and self.Name) or tostring(self)
			logAction("BindableEvent: " .. name)
			sendToDiscord("**Script event** `" .. tostring(name) .. "` (Bindable)\nArgs: " .. formatArgs(...))
		end
		return originalNamecall(self, ...)
	end

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
		local tweenInfo, instance, goalProps = args[1], args[2], args[3]
		local goalStr = formatTweenGoals(goalProps)
		logAction("TweenService:Create " .. (goalStr ~= "" and "→ " .. goalStr or ""))
		local targetName = (type(instance) == "userdata" and instance.Name) and instance.Name or safeStr(instance)
		sendToDiscord("**Tween (dash/move)**\nInstance: `" .. tostring(targetName) .. "`\n" .. (goalStr ~= "" and ("Goal: " .. goalStr) or "Goal: (see args)") .. "\nRecent:\n" .. recentActionsSummary())
		return originalNamecall(self, ...)
	end

	if method == "SetPrimaryPartCFrame" then
		local targetCF = args[1]
		local toPos = formatCFrameOrVector(targetCF)
		local fromPos = ""
		if type(self) == "userdata" and self.PrimaryPart and self.PrimaryPart.Position then
			fromPos = "From: " .. formatCFrameOrVector(self.PrimaryPart.Position) .. "\n"
		end
		logAction("SetPrimaryPartCFrame (teleport) → " .. toPos)
		sendToDiscord("**Teleport** SetPrimaryPartCFrame\n" .. fromPos .. "To: " .. toPos .. "\nRecent:\n" .. recentActionsSummary())
		return originalNamecall(self, ...)
	end

	if method == "Kick" then
		logAction("Kick called!")
		sendToDiscord("**Kick** called by " .. tostring(self.Name or self) .. "\nRecent:\n" .. recentActionsSummary())
		return originalNamecall(self, ...)
	end

	-- HTTP calls (e.g. Luarmor loader, API calls) – so you see what URLs the script hits
	if method == "GetAsync" or method == "HttpGet" or method == "PostAsync" or method == "HttpPost" then
		local url = type(args[1]) == "string" and args[1] or safeStr(args[1])
		-- Don't log our own webhook posts
		if url and not url:find("discord%.com/api/webhooks", 1, true) then
			logAction(method .. ": " .. url:sub(1, 100))
			sendToDiscord(("**%s**\n`%s`\n(Args: %s)"):format(method, url:sub(1, 500), formatArgs(...)))
		end
		return originalNamecall(self, ...)
	end

	-- GetService – which services the script uses (RunService, TweenService, etc.)
	if method == "GetService" then
		local svc = type(args[1]) == "string" and args[1] or safeStr(args[1])
		logAction("GetService: " .. tostring(svc))
		sendToDiscord("**GetService** `" .. tostring(svc) .. "`")
		return originalNamecall(self, ...)
	end

	-- Instance.new – what the script creates (GUI, parts, etc.)
	if method == "new" and args[1] then
		local className = type(args[1]) == "string" and args[1] or safeStr(args[1])
		logAction("Instance.new: " .. tostring(className))
		sendToDiscord("**Instance.new** `" .. tostring(className) .. "`")
		return originalNamecall(self, ...)
	end

	-- PivotTo – another way to move a model (like teleport)
	if method == "PivotTo" then
		local toPos = args[1] and formatCFrameOrVector(args[1]) or formatArgs(...)
		local name = (type(self) == "userdata" and self.Name) or tostring(self)
		logAction("PivotTo: " .. name .. " → " .. toPos)
		sendToDiscord("**PivotTo** (model move)\n`" .. tostring(name) .. "` → " .. toPos)
		return originalNamecall(self, ...)
	end

	-- Clone – what the script clones
	if method == "Clone" then
		local name = (type(self) == "userdata" and self.Name) or tostring(self)
		local class = (type(self) == "userdata" and self.ClassName) or "?"
		logAction("Clone: " .. class .. " " .. name)
		sendToDiscord("**Clone** `" .. tostring(class) .. "` " .. tostring(name))
		return originalNamecall(self, ...)
	end

	-- Destroy – what the script destroys
	if method == "Destroy" then
		local name = (type(self) == "userdata" and self.Name) or tostring(self)
		local full = (type(self) == "userdata" and self.GetFullName) and self:GetFullName() or name
		logAction("Destroy: " .. full)
		sendToDiscord("**Destroy** `" .. tostring(full) .. "`")
		return originalNamecall(self, ...)
	end

	-- Invoke (InvokeServer from server side or Invoke on BindableFunction)
	if method == "Invoke" then
		local className = type(self) == "userdata" and self.ClassName or ""
		if className == "RemoteFunction" then
			local path = type(self) == "userdata" and self.GetFullName and self:GetFullName() or tostring(self)
			local ret = originalNamecall(self, ...)
			logAction("Invoke (RemoteFunction): " .. path)
			sendToDiscord("**Invoke** (Remote)\n`" .. tostring(path) .. "`\nArgs: " .. formatArgs(...) .. "\nReturn: " .. safeStr(ret))
			return ret
		end
		return originalNamecall(self, ...)
	end

		return originalNamecall(self, ...)
	end)
	setreadonly(mt, true)
	metatableHooked = true
end)

-- Capture console/output errors (e.g. "attempt to call a nil value", animation failed) and send to Discord
pcall(function()
	if not game or type(game.GetService) ~= "function" then return end
	local LogService = game:GetService("LogService")
	if not LogService or not LogService.MessageOut then return end
	local lastLogSend = 0
	local LOG_THROTTLE = 1.5
	LogService.MessageOut:Connect(function(message, messageType, source)
		if type(message) ~= "string" or message == "" then return end
		if message:find("^%[OBSERVER%]") then return end
		local typ = tostring(messageType)
		-- MessageError = engine/runtime errors; MessageWarning = warnings; MessageOutput = print
		if typ == "Enum.LogMessageType.MessageError" or typ == "MessageError" or typ == "2" then
			logAction("Console ERROR: " .. message:sub(1, 50))
			sendToDiscord("**Console ERROR**\n" .. message:sub(1, 1900) .. (source and "\n`" .. tostring(source) .. "`" or ""))
		elseif typ == "Enum.LogMessageType.MessageWarning" or typ == "MessageWarning" or typ == "1" then
			if tick() - lastLogSend < LOG_THROTTLE then return end
			lastLogSend = tick()
			logAction("Console warn: " .. message:sub(1, 50))
			sendToDiscord("**Console warn**\n" .. message:sub(1, 1900))
		end
	end)
	logAction("LogService.MessageOut hooked – console errors will be sent to Discord.")
end)

-- Hook print, warn, error so script messages go to Discord (skipped if injector blocks global replace)
pcall(function()
	local orig_print = print
	local orig_warn = warn
	local orig_error = error
	function print(...)
		sendScriptPrint("print", ...)
		return orig_print(...)
	end
	function warn(...)
		local msg = formatPrintArgs(...)
		if msg ~= "" and not msg:find("^%[OBSERVER%]") then
			logAction("Script warn: " .. msg:sub(1, 60))
			sendToDiscord("**Script warn**\n" .. msg:sub(1, 1900))
		end
		return orig_warn(...)
	end
	local orig_error_typed = orig_error
	function error(msg, level)
		if type(msg) == "string" and msg ~= "" and not msg:find("^%[OBSERVER%]") then
			logAction("Script error: " .. msg:sub(1, 60))
			sendToDiscord("**Script error**\n" .. msg:sub(1, 1900))
		end
		return orig_error_typed(msg, level)
	end
end)

-- Flush buffered prints every so often (use spawn if available)
local schedule = (type(spawn) == "function" and spawn) or (type(task) == "table" and task.spawn) or function(f) pcall(f) end
pcall(function()
	schedule(function()
		while true do
			pcall(function() if wait then wait(PRINT_THROTTLE_SEC) end end)
			flushPrintBuffer()
		end
	end)
end)

pcall(sendFirstScriptToDiscord)

if metatableHooked then
	logAction("Observer loaded (full). Metatable + print/warn/error + LogService.")
	sendToDiscord("**Observer** ready (full mode). Remotes, Tween, Teleport, HTTP, print/warn/error, console errors → Discord. Run your script now.")
else
	logAction("Observer loaded (limited). No metatable hook (injector?). print/warn/error + LogService still work.")
	sendToDiscord("**Observer** ready (limited mode – injector may not support getrawmetatable). I will still report: **print** / warn / error, **console errors**. Run your script now.")
end
