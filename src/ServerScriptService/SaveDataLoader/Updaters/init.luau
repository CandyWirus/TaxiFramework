--[[

Updaters are used to update save files when reconcilation is not sufficient for one's use case. To make an updater, add a ModuleScript parented to this script
that returns a function that takes a Suphi DataStore.Value object as its first argument and updates said object. This is NOT a wrapper, nor a SharedTable.
Ordered values are present in this data and modifying them will reflect in their value in their corresponding OrderedDataStores. An example updater is shown below:


--1.luau (name is important!)
return function(data)
    local points = data[1]
    local seasonalPoints = data[9]
    data[9] = nil
    data[1] = points + seasonalPoints --Compensate players for any points they may have received from a seasonal event after it has ended by adding their seasonal points to their regular points.
end


--]]

--The following code is not an updater, it loads the updaters. Do not try to overwrite it with one.

local t = {}

local children = script:GetChildren()

for _, v in children do
    local name = v:GetAttribute("Version") or v.Name
    local num = tonumber(name)
    if (not num) or num ~= math.floor(num) then
        error(`Updater "{name}" is named incorrectly.`)
    end
    t[num] = require(v)
end

for i = 1, #children do
    if not t[i] then
        error(`Updater {i} not present.`)
    end
end

return t