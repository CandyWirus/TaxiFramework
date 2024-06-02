local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local serverModules = ServerStorage.Modules
local actor = script.Parent

local template = require(serverModules.SaveFileTemplate)
local SaveFileManipulator = require(serverModules.SaveFileManipulator)

local remote = ReplicatedStorage.Remotes.QuerySaveFile
local bindable = actor.FileChanged

remote.OnServerInvoke = function(player, iter, ...)
    local store = SaveFileManipulator.WaitForWrapper(player)
    if store then

		if iter == false and select("#", ...) == 1 and ... == 1 then --Hard-coded edge case for the first entry of the save file. If, due to a developer oversight, this value is not accessible, all clients will get banned upon joining.
			return store[1]
		end

        local currentTemplateValue = template
        local currentValue = store
        for _, key in {...} do
            local keyType = typeof(key)
            if keyType ~= "string" and keyType ~= "number" then
                SaveFileManipulator.Ban(store, "Exploiting", `QuerySaveFile: Got illegal key datatype: "{keyType}".`)
                return nil
            end

            local currentTemplateType = typeof(currentTemplateValue)
            if currentTemplateType == "table" then
                local metatable = getmetatable(currentTemplateValue)

                local generic
                if metatable then
                    local index = metatable.index
                    generic = metatable.generic

                    if index then
                        local isLegal = index(currentValue, key)
                        if not isLegal then
                            SaveFileManipulator.Ban(store, "Exploiting", `QuerySaveFile: Illegal index operation.`)
                        end
                    end
                end
                local nextTemplateValue = currentTemplateValue[key]
                if key == generic then
                    SaveFileManipulator.Ban(store, "Exploiting", `QuerySaveFile: Attempt to index generic value: "{generic}".`)
                elseif nextTemplateValue then
                    currentTemplateValue = nextTemplateValue
                elseif generic then
                    currentTemplateValue = currentTemplateValue[generic]
                end
                currentValue = currentValue[key]
                if currentValue == nil and generic then
                    SaveFileManipulator.Ban(store, "Exploiting", `QuerySaveFile: Attempt to query invalid generic: "{key}".`)
                end
            else
                SaveFileManipulator.Ban(store, "Exploiting", `QuerySaveFile: Attempt to index a {currentTemplateType} like a table.`)
                return nil
            end
        end

        if iter then
            local valueType = typeof(currentValue)
            if valueType == "SharedTable" or valueType == "table" then
                local metatable = getmetatable(currentTemplateValue)
                if metatable then
                    local iterCondition = metatable.iter
                    if iterCondition then
                        local t = {}
                        for i, v in currentValue do
                            if iterCondition == true or iterCondition(currentValue, i) then
                                local iterType = typeof(v)
                                if iterType == "SharedTable" or iterType == "table" then
                                    t[i] = {}
                                else
                                    t[i] = v
                                end
                            end
                        end
                        return t
                    end
                end
                SaveFileManipulator.Ban(store, "Exploiting", `QuerySaveFile: Illegal iter operation.`)
            else
                SaveFileManipulator.Ban(store, "Exploiting", `QuerySaveFile: Attempt to iterate a "{valueType}" value.`)
            end
        end

        local currentValueType = typeof(currentValue)
        if currentValueType == "SharedTable" or currentValueType == "table" then
            return {}
        else
            return currentValue
        end
    end
    return nil
end

local changedEvents = {}

bindable.Event:Connect(function(...)
	local args = {...}
	local storeId = table.remove(args, 1)
	local store = SaveFileManipulator.WaitForWrapper(storeId)

	if store then
		local currentTemplateValue = template
		local currentChangedValue = changedEvents
		local currentValue = store

		local clientLegal = true
		local clientReplicated = true

		for i, v in args do
			local currentTemplateType = typeof(currentTemplateValue)
			if currentTemplateType == "table" then
				local metatable = getmetatable(currentTemplateValue)
				local generic
				if metatable then
					local index = metatable.index
					generic = metatable.generic

					if index then
						local isLegal = index(currentValue, v)
						if not isLegal then
							clientLegal = false
						end
					end

					clientReplicated = metatable.ReplicatedEvents ~= false
				end
				local nextTemplateValue = currentTemplateValue[v]
				if v == generic then
					error(`Server attempt to index generic value: "{generic}".`)
				elseif nextTemplateValue then
					currentTemplateValue = nextTemplateValue
				elseif generic then
					currentTemplateValue = currentTemplateValue[generic]
				end
				currentValue = currentValue[v]
			else
				error(`Invalid template type: "{currentTemplateType}".`)
			end
		end

		if clientLegal and clientReplicated then
			local success, userId = pcall(function() return tonumber(string.match(string.split(storeId, "/")[3], "%d+")) end)
			if success and userId then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					local finalValueType = typeof(currentValue)
					local value
					if finalValueType == "table" or finalValueType == "SharedTable" then
						value = {}
					else
						value = currentValue
					end
					pcall(function(...) remote:InvokeClient(player, value, ...) end, select(2, ...))
				end
			end
		end
	end
end)