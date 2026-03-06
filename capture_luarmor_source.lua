--[[
  For LDPlayer / mobile executor.
  Saves EVERYTHING: loader, bootstrapper (Lua decryptor), and your real script.
  No Discord. Find folder "LuarmorCapture" and copy to PC via shared folder.
]]

local _K = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local _U = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"

local _n = 0
local _real = loadstring
local _folder = "LuarmorCapture"

local function isBootstrapper(s)
	if type(s) ~= "string" or #s < 500 then return false end
	local head = s:sub(1, 500)
	return head:find("Luarmor V4 bootstrapper") or head:find("static_content") or head:find("luarmor%.net")
end

local function _save(s)
	if type(s) ~= "string" or #s < 50 then return end
	_n = _n + 1
	(task and task.defer or spawn or function(f) f() end)(function()
		pcall(function()
			if not writefile then return end
			if makefolder then pcall(function() makefolder(_folder) end) end
			local base = _folder .. "/source_captured_" .. _n
			writefile(base .. ".lua", s)
			if isBootstrapper(s) then
				writefile(_folder .. "/source_BOOTSTRAPPER_DECRYPTOR.lua", s)
			else
				writefile(_folder .. "/source_REAL_SCRIPT.lua", s)
			end
		end)
		pcall(function()
			if setclipboard and #s < 100000 then setclipboard(s) end
		end)
	end)
end

loadstring = function(src, name)
	if type(src) == "string" then _save(src) end
	return _real(src, name)
end

script_key = _K
loadstring(game:HttpGet(_U))()
