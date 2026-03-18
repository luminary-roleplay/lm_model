---@class SubscriptionState
---@field mode string
---@field resources {all: table<string, boolean>, records: table<any, table<string, boolean>>}
---@field players {all: table<number, boolean>, records: table<any, table<number, boolean>>}

local SubscriptionFeature = {}

---@class SubscriptionFeatureStore: BaseStore
---@field subscribeResource fun(self: SubscriptionFeatureStore, resourceName: string): boolean
---@field unsubscribeResource fun(self: SubscriptionFeatureStore, resourceName: string): boolean
---@field subscribeResourceTo fun(self: SubscriptionFeatureStore, resourceName: string, id: any): boolean
---@field unsubscribeResourceFrom fun(self: SubscriptionFeatureStore, resourceName: string, id: any): boolean
---@field isResourceSubscribed fun(self: SubscriptionFeatureStore, resourceName: string, id?: any): boolean
---@field getSubscribedResources fun(self: SubscriptionFeatureStore, id?: any): string[]
---@field subscribePlayer fun(self: SubscriptionFeatureStore, playerId: any): boolean
---@field unsubscribePlayer fun(self: SubscriptionFeatureStore, playerId: any): boolean
---@field subscribePlayerTo fun(self: SubscriptionFeatureStore, playerId: any, id: any): boolean
---@field unsubscribePlayerFrom fun(self: SubscriptionFeatureStore, playerId: any, id: any): boolean
---@field isPlayerSubscribed fun(self: SubscriptionFeatureStore, playerId: any, id?: any): boolean
---@field getSubscribedPlayers fun(self: SubscriptionFeatureStore, id?: any): number[]
---@field serializeForPlayer fun(self: SubscriptionFeatureStore, playerId: any, context?: any): table<any, table>

---@param mode string
---@return boolean
local function supportsResources(mode)
    return mode == 'resource' or mode == 'both'
end

---@param mode string
---@return boolean
local function supportsPlayers(mode)
    return mode == 'player' or mode == 'both'
end

---@param playerId any
---@return number|nil
local function normalizePlayerId(playerId)
    local id = tonumber(playerId)

    if not id or id <= 0 then
        return nil
    end

    return id
end

---@param map table<any, table<any, boolean>>
---@param key any
---@return table<any, boolean>
local function ensureSubscriberMap(map, key)
    local subscribers = map[key]

    if not subscribers then
        subscribers = {}
        map[key] = subscribers
    end

    return subscribers
end

--- Attach resource-level subscriptions.
---@param store BaseStore
---@param options table
function SubscriptionFeature.attach(store, options)
    ---@cast store SubscriptionFeatureStore

    local eventName = options.eventName or store.eventName

    ---@type SubscriptionState
    store.featureState.subscriptions = {
        mode = options.mode or 'player',
        resources = {
            all = {},
            records = {},
        },
        players = {
            all = {},
            records = {},
        },
    }

    local mode = store.featureState.subscriptions.mode
    local resourceEnabled = supportsResources(mode)
    local playerEnabled = supportsPlayers(mode)

    --- Subscribe one resource to all updates.
    ---@param resourceName string
    ---@return boolean
    function store:subscribeResource(resourceName)
        if not resourceEnabled then return false end

        self.featureState.subscriptions.resources.all[resourceName] = true
        return true
    end

    --- Unsubscribe a resource from everything.
    ---@param resourceName string
    ---@return boolean
    function store:unsubscribeResource(resourceName)
        if not resourceEnabled then return false end

        self.featureState.subscriptions.resources.all[resourceName] = nil

        for id, subscribers in pairs(self.featureState.subscriptions.resources.records) do
            subscribers[resourceName] = nil

            if not next(subscribers) then
                self.featureState.subscriptions.resources.records[id] = nil
            end
        end

        return true
    end

    --- Subscribe one resource to one record.
    ---@param resourceName string
    ---@param id any
    ---@return boolean
    function store:subscribeResourceTo(resourceName, id)
        if not resourceEnabled then return false end

        local subscribers = ensureSubscriberMap(self.featureState.subscriptions.resources.records, id)

        subscribers[resourceName] = true
        return true
    end

    --- Unsubscribe one resource from one record.
    ---@param resourceName string
    ---@param id any
    ---@return boolean
    function store:unsubscribeResourceFrom(resourceName, id)
        if not resourceEnabled then return false end

        local subscribers = self.featureState.subscriptions.resources.records[id]
        if not subscribers then return false end

        subscribers[resourceName] = nil

        if not next(subscribers) then
            self.featureState.subscriptions.resources.records[id] = nil
        end

        return true
    end

    --- Check subscription state.
    ---@param resourceName string
    ---@param id any?
    ---@return boolean
    function store:isResourceSubscribed(resourceName, id)
        if not resourceEnabled then return false end

        if self.featureState.subscriptions.resources.all[resourceName] then
            return true
        end

        if id ~= nil then
            local subscribers = self.featureState.subscriptions.resources.records[id]
            return subscribers and subscribers[resourceName] == true or false
        end

        return false
    end

    --- Get all resource subscribers.
    ---@param id any?
    ---@return string[]
    function store:getSubscribedResources(id)
        if not resourceEnabled then
            return {}
        end

        local output = {}
        local seen = {}

        for resourceName in pairs(self.featureState.subscriptions.resources.all) do
            seen[resourceName] = true
            output[#output + 1] = resourceName
        end

        if id ~= nil then
            local subscribers = self.featureState.subscriptions.resources.records[id]
            if subscribers then
                for resourceName in pairs(subscribers) do
                    if not seen[resourceName] then
                        output[#output + 1] = resourceName
                    end
                end
            end
        end

        return output
    end

    --- Subscribe one player to all updates.
    ---@param playerId any
    ---@return boolean
    function store:subscribePlayer(playerId)
        if not playerEnabled then return false end

        local id = normalizePlayerId(playerId)
        if not id then return false end

        self.featureState.subscriptions.players.all[id] = true
        return true
    end

    --- Unsubscribe one player from everything.
    ---@param playerId any
    ---@return boolean
    function store:unsubscribePlayer(playerId)
        if not playerEnabled then return false end

        local id = normalizePlayerId(playerId)
        if not id then return false end

        self.featureState.subscriptions.players.all[id] = nil

        for recordId, subscribers in pairs(self.featureState.subscriptions.players.records) do
            subscribers[id] = nil

            if not next(subscribers) then
                self.featureState.subscriptions.players.records[recordId] = nil
            end
        end

        return true
    end

    --- Subscribe one player to one record.
    ---@param playerId any
    ---@param id any
    ---@return boolean
    function store:subscribePlayerTo(playerId, id)
        if not playerEnabled then return false end

        local src = normalizePlayerId(playerId)
        if not src then return false end

        local subscribers = ensureSubscriberMap(self.featureState.subscriptions.players.records, id)
        subscribers[src] = true

        return true
    end

    --- Unsubscribe one player from one record.
    ---@param playerId any
    ---@param id any
    ---@return boolean
    function store:unsubscribePlayerFrom(playerId, id)
        if not playerEnabled then return false end

        local src = normalizePlayerId(playerId)
        if not src then return false end

        local subscribers = self.featureState.subscriptions.players.records[id]
        if not subscribers then return false end

        subscribers[src] = nil

        if not next(subscribers) then
            self.featureState.subscriptions.players.records[id] = nil
        end

        return true
    end

    --- Check whether a player is subscribed.
    ---@param playerId any
    ---@param id any?
    ---@return boolean
    function store:isPlayerSubscribed(playerId, id)
        if not playerEnabled then return false end

        local src = normalizePlayerId(playerId)
        if not src then return false end

        if self.featureState.subscriptions.players.all[src] then
            return true
        end

        if id ~= nil then
            local subscribers = self.featureState.subscriptions.players.records[id]
            return subscribers and subscribers[src] == true or false
        end

        return false
    end

    --- Get all subscribed player IDs.
    ---@param id any?
    ---@return number[]
    function store:getSubscribedPlayers(id)
        if not playerEnabled then
            return {}
        end

        local output = {}
        local seen = {}

        for playerId in pairs(self.featureState.subscriptions.players.all) do
            seen[playerId] = true
            output[#output + 1] = playerId
        end

        if id ~= nil then
            local subscribers = self.featureState.subscriptions.players.records[id]
            if subscribers then
                for playerId in pairs(subscribers) do
                    if not seen[playerId] then
                        output[#output + 1] = playerId
                    end
                end
            end
        end

        return output
    end

    --- Serialize only records visible to one player.
    ---@param playerId any
    ---@param context any?
    ---@return table<any, table>
    function store:serializeForPlayer(playerId, context)
        if not playerEnabled then
            return self:serializeAll(context)
        end

        local output = {}

        for id, record in pairs(self.records) do
            if self:isPlayerSubscribed(playerId, id) then
                output[id] = record:toPublic(context)
            end
        end

        return output
    end

    if playerEnabled then
        RegisterNetEvent(('%s:subscribeAll'):format(eventName), function()
            local src = normalizePlayerId(source)
            if not src then return end

            store:subscribePlayer(src)

            local snapshot = store:serializeForPlayer(src, {
                source = src,
                requestType = 'client_subscribe_all',
                model = store.name,
            })

            for id, payload in pairs(snapshot) do
                TriggerClientEvent(('%s:create'):format(eventName), src, id, payload)
            end
        end)

        RegisterNetEvent(('%s:unsubscribeAll'):format(eventName), function()
            local src = normalizePlayerId(source)
            if not src then return end

            local snapshot = store:serializeForPlayer(src, {
                source = src,
                requestType = 'client_unsubscribe_all',
                model = store.name,
            })

            store:unsubscribePlayer(src)

            for id in pairs(snapshot) do
                TriggerClientEvent(('%s:delete'):format(eventName), src, id)
            end
        end)

        RegisterNetEvent(('%s:subscribe'):format(eventName), function(id)
            local src = normalizePlayerId(source)
            if not src then return end

            if not store:subscribePlayerTo(src, id) then
                return
            end

            local payload = store:serializeOne(id, {
                source = src,
                requestType = 'client_subscribe',
                model = store.name,
                id = id,
            })

            if payload then
                TriggerClientEvent(('%s:create'):format(eventName), src, id, payload)
            end
        end)

        RegisterNetEvent(('%s:unsubscribe'):format(eventName), function(id)
            local src = normalizePlayerId(source)
            if not src then return end

            if store:unsubscribePlayerFrom(src, id) then
                TriggerClientEvent(('%s:delete'):format(eventName), src, id)
            end
        end)

        AddEventHandler('playerDropped', function()
            store:unsubscribePlayer(source)
        end)
    end
end

return SubscriptionFeature
