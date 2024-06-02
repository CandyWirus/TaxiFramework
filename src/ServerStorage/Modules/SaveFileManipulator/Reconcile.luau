local reconcile
reconcile = function(file, template)
	local fileType = typeof(file)
	local metatable = getmetatable(template)
	local generic = metatable and metatable.generic
	for i, v in template do
		if i ~= generic and file[i] == nil then
			if typeof(v) == "table" then
				local t = fileType == "SharedTable" and SharedTable.new() or {}
				file[i] = t
				reconcile(t, v)
			else
				file[i] = v
			end
		end
	end

	if generic then
		for i, v in file do
			if template[i] == nil then
				reconcile(v, file[generic])
			end
		end
	end
end

return reconcile