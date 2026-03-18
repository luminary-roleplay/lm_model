---@class ClientModelConnection: SharedBaseContainer
---@field definition RegisteredModelDefinition
---@field config table
---@field recordClass table
local ClientModelConnection = lib.class('ClientModelConnection', require('@lm_model.shared.base_container'))

local ClientModel = {}

---@param definition RegisteredModelDefinition
---@param config table
function ClientModelConnection:constructor(definition, config)
    self:super()

    self.definition = definition
    self.config = config
    self.recordClass = (config.features.remote and config.features.remote.recordClass)
        or (config.features.mirror and config.features.mirror.recordClass)
        or require('@lm_model.client.record')

    self:_setup(config.features)
end

--- Setup client mirror/proxy behavior.
---@param features table
function ClientModelConnection:_setup(features)
    local mirrorOptions = features.remote or features.mirror or {}
    local eventName = self.definition.eventName

    if mirrorOptions.autoLoad ~= false then
        self:resync()
    end

    if mirrorOptions.autoListen ~= false then
        RegisterNetEvent(('%s:create'):format(eventName), function(id, payload)
            self.records[id] = self:_wrapRecord(id, payload)
        end)

        RegisterNetEvent(('%s:updateData'):format(eventName), function(id, diff)
            self:_applyDiff(id, diff)
        end)

        RegisterNetEvent(('%s:updateState'):format(eventName), function(id, diff)
            self:_applyDiff(id, diff)
        end)

        RegisterNetEvent(('%s:delete'):format(eventName), function(id)
            self.records[id] = nil
        end)
    end
end

--- Reload full snapshot from server.
---@return table<any, any>
function ClientModelConnection:resync()
    local all = lib.callback.await(('%s:getAll'):format(self.definition.eventName), false)
    self.records = {}

    for id, payload in pairs(all or {}) do
        self.records[id] = self:_wrapRecord(id, payload)
    end

    return self.records
end

--- Build one request event name.
---@param name string
---@return string
function ClientModelConnection:_event(name)
    return ('%s:%s'):format(self.definition.eventName, name)
end

--- Request a store method from server.
---@param methodName string
---@param ... any
---@return boolean
function ClientModelConnection:requestStore(methodName, ...)
    TriggerServerEvent(self:_event('requestStore'), methodName, ...)
    return true
end

--- Request a record method from server.
---@param id any
---@param methodName string
---@param ... any
---@return boolean
function ClientModelConnection:requestRecord(id, methodName, ...)
    TriggerServerEvent(self:_event('requestRecord'), id, methodName, ...)
    return true
end

--- Small convenience wrappers.
---@param id any
---@return boolean
function ClientModelConnection:lock(id)
    return self:requestStore('lock', id)
end

---@param id any
---@return boolean
function ClientModelConnection:unlock(id)
    return self:requestStore('unlock', id)
end

---@param id any
---@return boolean
function ClientModelConnection:subscribeTo(id)
    TriggerServerEvent(self:_event('subscribe'), id)
    return true
end

---@param id any
---@return boolean
function ClientModelConnection:unsubscribeFrom(id)
    TriggerServerEvent(self:_event('unsubscribe'), id)
    return true
end

---@return boolean
function ClientModelConnection:subscribe()
    TriggerServerEvent(self:_event('subscribeAll'))
    return true
end

---@return boolean
function ClientModelConnection:unsubscribe()
    TriggerServerEvent(self:_event('unsubscribeAll'))
    return true
end

--- Connect to a server-owned client-synced model.
---@param config {model:string, features?:table}
---@return ClientModelConnection
function ClientModel.connect(config)
    assert(type(config) == 'table', 'config must be a table')
    assert(type(config.model) == 'string', 'config.model is required')

    local definition = lib.callback.await('lm_model:getModelDefinition', false, config.model)
    if not definition then
        error(('model "%s" is not registered'):format(config.model), 2)
    end

    if not definition.features.sync then
        error(('model "%s" does not support client sync'):format(config.model), 2)
    end

    local features = config.features or {
        remote = true,
    }

    return ClientModelConnection:new(definition, {
        features = features,
    })
end

return ClientModel