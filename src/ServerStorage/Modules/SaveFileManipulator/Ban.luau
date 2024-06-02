local GetPlayerFromFile = require(script.Parent.GetPlayerFromFile)

return function(file, reason: string, detection: string, now: boolean?, length: number?)
	--Bans are implemented by the developer
	--File: The save file/wrapper object.
	--Reason: The user-facing reason for being banned
	--Detection: The internal reason for being banned. In automated detections, this can be detailed information about how the ban was triggered. For manual bans, it can be the username of the admin who banned the player along with a notice that it was a manual ban.
	--Now: If set to true, ban the player immediately. Otherwise, ban them after a random amount of time in order to prevent reversing the anticheat. You must implement deferred ban functionality on your own.
	--Length: Amount of time, in seconds, a ban should last for.

	--The following code warns to the server-sided console when a player is flagged to be banned. It is not visible to clients, and it is actually recommended to keep it and add your own ban functionality below it.

	local player: Player? = GetPlayerFromFile(file)
	if player then
		local name: string = nil
		if typeof(player) == "Instance" then
			name = player.Name
		else
			name = `User ID {player}`
		end

		warn(`{name} has been flagged for {reason}, and will be banned.\n\t{detection}`)
	end

	--Your ban code here.
end