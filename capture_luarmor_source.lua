--[[
  For LDPlayer / mobile executor.
  Saves captured script to FILES only (no Discord). You copy files to PC via LDPlayer shared folder.
  After run: find folder "LuarmorCapture" in executor files, copy source_captured_2.lua and
  source_captured_3.lua to PC. The one that does NOT start with "Luarmor V4 bootstrapper" is your script.
]]

local _K = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local _U = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"

local _n = 0
local _real = loadstring
local _folder = "LuarmorCapture"

-- Returns true if this looks like the Luarmor bootstrapper (not the real script)
local function isBootstrapper(s)
	if type(s) ~= "string" or #s < 500 then return false end
	local head = s:sub(1, 500)
	return head:find("Luarmor V4 bootstrapper") or head:find("static_content") or head:find("luarmor%.net")
end

local function _save(s)
	if type(s) ~= "string" or #s < 600 then return end
	_n = _n + 1
	(task and task.defer or spawn or function(f) f() end)(function()
		pcall(function()
			if not writefile then return end
			if makefolder then pcall(function() makefolder(_folder) end) end
			local fname = _folder .. "/source_captured_" .. _n .. ".lua"
			writefile(fname, s)
			-- Also save the one that is NOT bootstrapper as "real script" so you know which to open
			if not isBootstrapper(s) then
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
