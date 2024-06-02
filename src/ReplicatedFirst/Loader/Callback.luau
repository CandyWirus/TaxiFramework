--[[ PSEUDOCODE FOR A LOADING SCREEN. The code in this block runs instantly upon joining the game.

local Players = game:GetService("Players")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

local loadingScreenGui = Instance.new("ScreenGui")
loadingScreenGui.Parent = player:WaitForChild("PlayerGui")

--]]


local onGameLoaded = function(elapsed: number)
	print(`Game client loaded in {string.format("%.2f", elapsed)} seconds.`)

	--[[ PSEUDOCODE FOR A LOADING SCREEN. The code in this block and its enclosing function runs after the ModuleScript returns and all client Actors mark themselves as loaded

	loadingScreenGui:Destroy()

	--]]
end

return onGameLoaded