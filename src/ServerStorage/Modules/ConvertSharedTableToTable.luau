local createTableFromSharedTable
createTableFromSharedTable = function(sharedTable)
	local newT = {}
	local isMixed = false
	local lastType = nil
	for i, v in sharedTable do
		local currentType = typeof(i)
		if lastType and lastType ~= currentType then
			isMixed = true
		else
			lastType = currentType
		end
		---@diagnostic disable-next-line: invalid-class-name
		if typeof(v) == "SharedTable" then
			local subTable, isSubtableMixed = createTableFromSharedTable(v)
			isMixed = isMixed or isSubtableMixed
			newT[i] = subTable
		else
			newT[i] = v
		end
	end
	return newT, isMixed
end

return createTableFromSharedTable