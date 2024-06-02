local startTime = tick()

local ServerScriptService = game:GetService("ServerScriptService")

local actor = script.Parent
local onGameLoaded = require(actor.Callback)

local disconnectAll = function(connections)
	for _, v in connections do
		v:Disconnect()
	end
	table.clear(connections)
end

local thread = coroutine.running()
for _, v in ServerScriptService:GetChildren() do
	if v:IsA("Actor") and v ~= actor then
		if not v:GetAttribute("Loaded") then
			local connections = {}

			local allScriptsLoaded = true
			local actorScripts = {}
			for _, v2 in v:GetDescendants() do
				if v2:IsA("Script") then
					table.insert(actorScripts, v2)
				end
			end
			for _, v2 in actorScripts do
				if not v2:GetAttribute("Loaded") then
					allScriptsLoaded = false
					table.insert(connections, v2:GetAttributeChangedSignal("Loaded"):Connect(function()
						local allScriptsLoaded = true
						for _, v3 in actorScripts do
							if not v3:GetAttribute("Loaded") then
								allScriptsLoaded = false
								break
							end
						end
						if allScriptsLoaded then
							disconnectAll(connections)
							assert(coroutine.resume(thread))
						end
					end))
				end
			end

			if allScriptsLoaded then
				v:SetAttribute("Loaded", true)
				continue
			end

			table.insert(connections, v:GetAttributeChangedSignal("Loaded"):Connect(function()
				if v:GetAttribute("Loaded") then
					disconnectAll(connections)
					assert(coroutine.resume(thread))
				end
			end))

			coroutine.yield()
			v:SetAttribute("Loaded", true)
		end
	end
end

actor:SetAttribute("Loaded", true)
onGameLoaded(tick() - startTime)