--!nonstrict
-- Collects things to clean up: Instances (Destroy), connections (Disconnect),
-- threads (task.cancel) and functions (called).

export type Janitor = {
	Add: <T>(self: Janitor, item: T) -> T,
	Cleanup: (self: Janitor) -> (),
	Destroy: (self: Janitor) -> (),
}

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new(): Janitor
	return (setmetatable({ _items = {} }, Janitor) :: any) :: Janitor
end

function Janitor:Add(item)
	table.insert(self._items, item)
	return item
end

local function clean(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "function" then
		item()
	elseif kind == "table" then
		if item.Destroy then
			item:Destroy()
		elseif item.Disconnect then
			item:Disconnect()
		end
	end
end

function Janitor:Cleanup()
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		clean(items[index])
	end
end

Janitor.Destroy = Janitor.Cleanup

return Janitor
