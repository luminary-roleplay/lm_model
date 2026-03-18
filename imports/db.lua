---@class LmModelDbAdapter
---@field query fun(query: string, params?: table): table
---@field single fun(query: string, params?: table): table|nil
---@field scalar fun(query: string, params?: table): any
---@field insert fun(query: string, params?: table): number|nil
---@field update fun(query: string, params?: table): number
---@field execute fun(query: string, params?: table): number
---@field transaction fun(queries: table, params?: table): boolean
---@field prepare fun(query: string, params?: table): table
---@field queryFile fun(path: string, params?: table): table
---@field singleFile fun(path: string, params?: table): table|nil
---@field scalarFile fun(path: string, params?: table): any
---@field insertFile fun(path: string, params?: table): number|nil
---@field updateFile fun(path: string, params?: table): number
---@field executeFile fun(path: string, params?: table): number
---@field loadQuery fun(path: string): string
---@field hasDependency boolean
---@field usingExports boolean

local currentResource = GetCurrentResourceName()
local hasMySQLGlobal = rawget(_G, 'MySQL') ~= nil

---@param resourceName string
---@param dependencyName string
---@return boolean
local function hasDependency(resourceName, dependencyName)
    local count = GetNumResourceMetadata(resourceName, 'dependency')

    for i = 0, count - 1 do
        local value = GetResourceMetadata(resourceName, 'dependency', i)
        if value == dependencyName then
            return true
        end
    end

    return false
end

---@param resourceName string
---@param path string
---@return string
local function loadQuery(resourceName, path)
    local query = LoadResourceFile(resourceName, path)

    if not query then
        error(("Failed to load SQL file '%s' from resource '%s'"):format(path, resourceName), 2)
    end

    return query
end

local declaredOxmysqlDependency = hasDependency(currentResource, 'oxmysql')
local oxmysqlState = GetResourceState('oxmysql')

-- Fail early if oxmysql is unavailable.
if oxmysqlState ~= 'started' then
    if declaredOxmysqlDependency then
        error(
            ("Resource '%s' loaded lm_model DB module and declares dependency 'oxmysql', but oxmysql is not started. " ..
            "Make sure 'ensure oxmysql' is above '%s'."):format(currentResource, currentResource),
            2
        )
    end

    error(
        ("Resource '%s' loaded lm_model DB module, but oxmysql is not started. " ..
        "Start oxmysql first or remove the DB feature/module from this resource."):format(currentResource),
        2
    )
end

-- Warn when falling back to exports.
if not declaredOxmysqlDependency then
    print(("[lm_model] Resource '%s' loaded the DB module without declaring dependency 'oxmysql'. " ..
        "Falling back to exports.oxmysql. Consider adding `dependency 'oxmysql'` to the resource manifest.")
        :format(currentResource))
end

---@type LmModelDbAdapter
local Db = {
    hasDependency = declaredOxmysqlDependency,
    usingExports = not declaredOxmysqlDependency or not hasMySQLGlobal,
}

---@param query string
---@param params table?
---@return table
function Db.query(query, params)
    if declaredOxmysqlDependency and hasMySQLGlobal then
        return MySQL.query.await(query, params or {})
    end

    return exports.oxmysql:query_async(query, params or {})
end

---@param query string
---@param params table?
---@return table|nil
function Db.single(query, params)
    if declaredOxmysqlDependency and hasMySQLGlobal then
        return MySQL.single.await(query, params or {})
    end

    return exports.oxmysql:single_async(query, params or {})
end

---@param query string
---@param params table?
---@return any
function Db.scalar(query, params)
    if declaredOxmysqlDependency and hasMySQLGlobal then
        return MySQL.scalar.await(query, params or {})
    end

    return exports.oxmysql:scalar_async(query, params or {})
end

---@param query string
---@param params table?
---@return number|nil
function Db.insert(query, params)
    if declaredOxmysqlDependency and hasMySQLGlobal then
        return MySQL.insert.await(query, params or {})
    end

    return exports.oxmysql:insert_async(query, params or {})
end

---@param query string
---@param params table?
---@return number
function Db.update(query, params)
    if declaredOxmysqlDependency and hasMySQLGlobal then
        return MySQL.update.await(query, params or {}) or 0
    end

    return exports.oxmysql:update_async(query, params or {}) or 0
end

---@param query string
---@param params table?
---@return number
function Db.execute(query, params)
    if declaredOxmysqlDependency and hasMySQLGlobal then
        return MySQL.rawExecute.await(query, params or {}) or 0
    end

    return exports.oxmysql:execute_async(query, params or {}) or 0
end

---@param queries table
---@param params table?
---@return boolean
function Db.transaction(queries, params)
    if declaredOxmysqlDependency and hasMySQLGlobal then
        return MySQL.transaction.await(queries, params or {})
    end

    return exports.oxmysql:transaction_async(queries, params or {})
end

---@param query string
---@param params table?
---@return table
function Db.prepare(query, params)
    if declaredOxmysqlDependency and hasMySQLGlobal then
        return MySQL.prepare.await(query, params or {})
    end

    return exports.oxmysql:prepare_async(query, params or {})
end

---@param path string
---@return string
function Db.loadQuery(path)
    return loadQuery(currentResource, path)
end

---@param path string
---@param params table?
---@return table
function Db.queryFile(path, params)
    return Db.query(Db.loadQuery(path), params)
end

---@param path string
---@param params table?
---@return table|nil
function Db.singleFile(path, params)
    return Db.single(Db.loadQuery(path), params)
end

---@param path string
---@param params table?
---@return any
function Db.scalarFile(path, params)
    return Db.scalar(Db.loadQuery(path), params)
end

---@param path string
---@param params table?
---@return number|nil
function Db.insertFile(path, params)
    return Db.insert(Db.loadQuery(path), params)
end

---@param path string
---@param params table?
---@return number
function Db.updateFile(path, params)
    return Db.update(Db.loadQuery(path), params)
end

---@param path string
---@param params table?
---@return number
function Db.executeFile(path, params)
    return Db.execute(Db.loadQuery(path), params)
end

return Db