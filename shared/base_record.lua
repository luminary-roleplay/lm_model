---@class SharedBaseRecord
---@field manager any
---@field id any
---@field data table
local SharedBaseRecord = lib.class('SharedBaseRecord')

---@param manager any
---@param id any
---@param data table
function SharedBaseRecord:constructor(manager, id, data)
    self.manager = manager
    self.id = id
    self.data = data or {}
end

--- Get a field from the record data.
---@param key string
---@return any
function SharedBaseRecord:get(key)
    return self.data[key]
end

return SharedBaseRecord