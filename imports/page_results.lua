---@meta

---@generic T
---@class LmModelPagedResult<T>
---@field items T[]
---@field cursor integer
---@field nextCursor integer|nil
---@field total integer

---@generic TInput, TOutput
---@class LmModelPagedCallbackOptions<TInput, TOutput>
---@field getItems fun(source: number, ...: any): table
---@field map fun(item: TInput, source: number, ...: any): TOutput|nil
---@field sort fun(a: TInput, b: TInput): boolean
---@field before fun(source: number): nil
---@field minPageSize integer
---@field maxPageSize integer
---@field defaultPageSize integer

---@class LmModelPageResultsModule
---@field registerCallback fun(callbackName: string, options: LmModelPagedCallbackOptions<any, any>)?
---@field registerPagedCallback fun(callbackName: string, options: LmModelPagedCallbackOptions<any, any>)?
---@field loadDataset fun(callbackName: string, pageSize?: integer, map?: fun(item: any, index: integer): any, ...: any): table|nil, boolean, integer|nil
---@field loadPagedDataset fun(callbackName: string, pageSize?: integer, map?: fun(item: any, index: integer): any, ...: any): table|nil, boolean, integer|nil

---@param callbackName string
---@param options LmModelPagedCallbackOptions<any, any>
---@return fun(source: number, cursor: integer, pageSize: integer, ...: any): LmModelPagedResult<any>
local function buildPagedHandler(callbackName, options)
    if type(callbackName) ~= 'string' or callbackName == '' then
        error('expected callbackName to be a non-empty string', 3)
    end

    if type(options) ~= 'table' then
        error('expected options to be a table', 3)
    end

    if type(options.getItems) ~= 'function' then
        error('expected options.getItems to be a function', 3)
    end

    if type(options.map) ~= 'function' then
        error('expected options.map to be a function', 3)
    end

    return function(source, cursor, pageSize, ...)
        local before = options.before
        if type(before) == 'function' then
            before(source)
        end

        local items = {}
        local sourceItems = options.getItems(source, ...) or {}

        for _, value in pairs(sourceItems) do
            items[#items + 1] = value
        end

        local sorter = options.sort
        if type(sorter) == 'function' then
            table.sort(items, sorter)
        end

        local minPageSize = math.max(1, tonumber(options.minPageSize) or 25)
        local maxPageSize = math.max(minPageSize, tonumber(options.maxPageSize) or 500)
        local defaultPageSize = math.max(minPageSize,
            math.min(maxPageSize, tonumber(options.defaultPageSize) or 150))

        local total = #items
        local startIndex = math.max(1, tonumber(cursor) or 1)
        local limit = math.max(minPageSize, math.min(maxPageSize, tonumber(pageSize) or defaultPageSize))
        local lastIndex = math.min(total, startIndex + limit - 1)
        local pageItems = {}

        for index = startIndex, lastIndex do
            local mapped = options.map(items[index], source, ...)
            if mapped ~= nil then
                pageItems[#pageItems + 1] = mapped
            end
        end

        local nextCursor = nil
        if lastIndex < total then
            nextCursor = lastIndex + 1
        end

        ---@type LmModelPagedResult<any>
        return {
            items = pageItems,
            cursor = startIndex,
            nextCursor = nextCursor,
            total = total,
        }
    end
end

---@param callbackName string
---@param options LmModelPagedCallbackOptions<any, any>
local function registerPagedCallback(callbackName, options)
    local handler = buildPagedHandler(callbackName, options)
    lib.callback.register(callbackName, handler)
end

---@param callbackName string
---@param pageSize integer|nil
---@param map fun(item: any, index: integer): any
---@param ... any
---@return table|nil
---@return boolean
---@return integer|nil
local function loadPagedDataset(callbackName, pageSize, map, ...)
    if type(callbackName) ~= 'string' or callbackName == '' then
        error('expected callbackName to be a non-empty string', 2)
    end

    local output = {}
    local cursor = 1
    local usedPagedLoading = false
    local total = nil
    local extraArgs = { ... }

    while true do
        local page = lib.callback.await(callbackName, false, cursor, pageSize or 150, table.unpack(extraArgs))

        if type(page) ~= 'table' or type(page.items) ~= 'table' then
            if usedPagedLoading then
                break
            end

            return nil, false, nil
        end

        usedPagedLoading = true
        total = tonumber(page.total) or total

        for index = 1, #page.items do
            local item = page.items[index]

            if type(map) == 'function' then
                item = map(item, index)
            end

            if item ~= nil then
                output[#output + 1] = item
            end
        end

        if not page.nextCursor then
            break
        end

        cursor = tonumber(page.nextCursor) or 0
        if cursor < 1 then
            break
        end

        Wait(0)
    end

    return output, true, total
end

---@type LmModelPageResultsModule
local PageResults = {
    loadDataset = loadPagedDataset,
    loadPagedDataset = loadPagedDataset,
}

if IsDuplicityVersion() then
    PageResults.registerCallback = registerPagedCallback
    PageResults.registerPagedCallback = registerPagedCallback
end

return PageResults