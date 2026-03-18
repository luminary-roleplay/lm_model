---@class SyncFeatureOptions
---@field eventName string?
---@field clients boolean?
---@field registerCallbacks boolean?

local SyncFeature = {}

---@class SyncFeatureStore: BaseStore
---@field getSubscribedResources? fun(self: SyncFeatureStore, id?: any): string[]
---@field getSubscribedPlayers? fun(self: SyncFeatureStore, id?: any): number[]
---@field isPlayerSubscribed? fun(self: SyncFeatureStore, playerId: any, id?: any): boolean
---@field serializeForPlayer? fun(self: SyncFeatureStore, playerId: any, context?: any): table<any, table>
---@field _getSyncTargets fun(self: SyncFeatureStore, id: any): string[]
---@field _getSyncPlayers fun(self: SyncFeatureStore, id: any): number[]|nil
---@field _broadcastCreate fun(self: SyncFeatureStore, record: ModelRecord, context?: any)
---@field _broadcastUpdateData fun(self: SyncFeatureStore, record: ModelRecord, diff: table, context?: any)
---@field _broadcastUpdateState fun(self: SyncFeatureStore, record: ModelRecord, diff: table, context?: any)
---@field _broadcastDelete fun(self: SyncFeatureStore, id: any, context?: any)

--- Attach resource/client sync broadcasting.
---@param store BaseStore
---@param options SyncFeatureOptions
function SyncFeature.attach(store, options)
    ---@cast store SyncFeatureStore

    local eventName = options.eventName or store.eventName
    local syncClients = options.clients == true
    local hasSubscriptions = store.featureState.subscriptions ~= nil

    store.featureState.sync = {
        eventName = eventName,
        clients = syncClients,
    }

    -- Register default snapshot callbacks.
    if options.registerCallbacks ~= false then
        lib.callback.register(('%s:getAll'):format(eventName), function(source)
            if hasSubscriptions and type(store.serializeForPlayer) == 'function' and type(source) == 'number' and source > 0 then
                return store:serializeForPlayer(source)
            end

            return store:serializeAll()
        end)

        lib.callback.register(('%s:getOne'):format(eventName), function(source, id)
            if hasSubscriptions and type(store.isPlayerSubscribed) == 'function' and type(source) == 'number' and source > 0 then
                if not store:isPlayerSubscribed(source, id) then
                    return nil
                end
            end

            return store:serializeOne(id)
        end)
    end

    --- Resolve target resources.
    ---@param id any
    ---@return string[]
    function store:_getSyncTargets(id)
        if hasSubscriptions then
            return self:getSubscribedResources(id)
        end

        return {}
    end

    --- Resolve target players.
    ---@param id any
    ---@return number[]|nil
    function store:_getSyncPlayers(id)
        if not syncClients then
            return nil
        end

        if hasSubscriptions and type(self.getSubscribedPlayers) == 'function' then
            return self:getSubscribedPlayers(id)
        end

        return nil
    end

    --- Broadcast create.
    ---@param record ModelRecord
    ---@param context any?
    function store:_broadcastCreate(record, context)
        local payload = record:toPublic(context)
        local targets = self:_getSyncTargets(record.id)
        local players = self:_getSyncPlayers(record.id)

        for i = 1, #targets do
            TriggerEvent(('%s:create'):format(eventName), targets[i], record.id, payload, context)
        end

        if players then
            for i = 1, #players do
                TriggerClientEvent(('%s:create'):format(eventName), players[i], record.id, payload)
            end
        elseif syncClients then
            TriggerClientEvent(('%s:create'):format(eventName), -1, record.id, payload)
        end
    end

    --- Broadcast persisted data diff.
    ---@param record ModelRecord
    ---@param diff table
    ---@param context any?
    function store:_broadcastUpdateData(record, diff, context)
        local targets = self:_getSyncTargets(record.id)
        local players = self:_getSyncPlayers(record.id)

        for i = 1, #targets do
            TriggerEvent(('%s:updateData'):format(eventName), targets[i], record.id, diff, context)
        end

        if players then
            for i = 1, #players do
                TriggerClientEvent(('%s:updateData'):format(eventName), players[i], record.id, diff)
            end
        elseif syncClients then
            TriggerClientEvent(('%s:updateData'):format(eventName), -1, record.id, diff)
        end
    end

    --- Broadcast runtime state diff.
    ---@param record ModelRecord
    ---@param diff table
    ---@param context any?
    function store:_broadcastUpdateState(record, diff, context)
        local targets = self:_getSyncTargets(record.id)
        local players = self:_getSyncPlayers(record.id)

        for i = 1, #targets do
            TriggerEvent(('%s:updateState'):format(eventName), targets[i], record.id, diff, context)
        end

        if players then
            for i = 1, #players do
                TriggerClientEvent(('%s:updateState'):format(eventName), players[i], record.id, diff)
            end
        elseif syncClients then
            TriggerClientEvent(('%s:updateState'):format(eventName), -1, record.id, diff)
        end
    end

    --- Broadcast delete.
    ---@param id any
    ---@param context any?
    function store:_broadcastDelete(id, context)
        local targets = self:_getSyncTargets(id)
        local players = self:_getSyncPlayers(id)

        for i = 1, #targets do
            TriggerEvent(('%s:delete'):format(eventName), targets[i], id, context)
        end

        if players then
            for i = 1, #players do
                TriggerClientEvent(('%s:delete'):format(eventName), players[i], id)
            end
        elseif syncClients then
            TriggerClientEvent(('%s:delete'):format(eventName), -1, id)
        end
    end

    local baseCreate = store.create

    -- Wrap create for sync.
    function store:create(data, context)
        local record, err = baseCreate(self, data, context)
        if not record then
            return record, err
        end

        self:_broadcastCreate(record, context)
        return record
    end

    local baseDelete = store.delete

    -- Wrap delete for sync.
    function store:delete(id, context)
        local ok, err = baseDelete(self, id, context)
        if ok then
            self:_broadcastDelete(id, context)
        end

        return ok, err
    end

    local baseEmitDataChanged = store._emitDataChanged

    -- Wrap persisted change emit for sync.
    function store:_emitDataChanged(record, key, oldValue, newValue, context)
        baseEmitDataChanged(self, record, key, oldValue, newValue, context)
        self:_broadcastUpdateData(record, {
            [key] = newValue,
            version = record.version,
        }, context)
    end

    local baseEmitStateChanged = store._emitStateChanged

    -- Wrap runtime change emit for sync.
    function store:_emitStateChanged(record, key, oldValue, newValue, context)
        baseEmitStateChanged(self, record, key, oldValue, newValue, context)
        self:_broadcastUpdateState(record, {
            [key] = newValue,
        }, context)
    end
end

return SyncFeature
