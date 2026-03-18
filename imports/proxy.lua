---@class StoreProxy
---@field resourceName string
---@field prefix string
local StoreProxy = lib.class('StoreProxy')

---@class RecordProxy
---@field resourceName string
---@field prefix string
---@field id any
local RecordProxy = lib.class('RecordProxy')

---@param resourceName string
---@param prefix string
---@param id any
function RecordProxy:constructor(resourceName, prefix, id)
    self.resourceName = resourceName
    self.prefix = prefix
    self.id = id
end

--- Invoke a record method remotely.
---@param methodName string
---@param ... any
---@return any
function RecordProxy:_invoke(methodName, ...)
    return exports[self.resourceName][('invoke%sRecord'):format(self.prefix)](self.id, methodName, ...)
end

RecordProxy.__index = function(self, key)
    local method = RecordProxy[key]
    if method ~= nil then
        return method
    end

    if type(key) == 'string' and key:sub(1, 1) == '_' then
        return nil
    end

    return function(_, ...)
        return self:_invoke(key, ...)
    end
end

RecordProxy.__newindex = function(self, key, value)
    rawset(self, key, value)
end

---@param resourceName string
---@param prefix string
function StoreProxy:constructor(resourceName, prefix)
    self.resourceName = resourceName
    self.prefix = prefix
end

--- Invoke a store method remotely.
---@param methodName string
---@param ... any
---@return any
function StoreProxy:_invoke(methodName, ...)
    return exports[self.resourceName][('invoke%sStore'):format(self.prefix)](methodName, ...)
end

---@param id any
---@return RecordProxy
function StoreProxy:record(id)
    return RecordProxy:new(self.resourceName, self.prefix, id)
end

StoreProxy.__index = function(self, key)
    local method = StoreProxy[key]
    if method ~= nil then
        return method
    end

    if type(key) == 'string' and key:sub(1, 1) == '_' then
        return nil
    end

    return function(_, ...)
        return self:_invoke(key, ...)
    end
end

StoreProxy.__newindex = function(self, key, value)
    rawset(self, key, value)
end

return setmetatable({
    StoreProxy = StoreProxy,
    RecordProxy = RecordProxy,
    new = function(resourceName, prefix)
        return StoreProxy:new(resourceName, prefix)
    end,
}, {
    __call = function(_, resourceName, prefix)
        return StoreProxy:new(resourceName, prefix)
    end,
})