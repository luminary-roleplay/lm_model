---@class LmModelSharedUtils
local SharedUtils = {}

--- Deep compare two values.
---@param a any
---@param b any
---@return boolean
function SharedUtils.deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return false end

    for key, value in pairs(a) do
        if not SharedUtils.deepEqual(value, b[key]) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

--- Deep clone a value.
---@param value any
---@return any
function SharedUtils.deepClone(value)
    if type(value) ~= 'table' then
        return value
    end

    local output = {}

    for key, entry in pairs(value) do
        output[key] = SharedUtils.deepClone(entry)
    end

    return output
end

--- Merge a diff into a target table.
---@param target table
---@param changes table
---@return table
function SharedUtils.mergeInto(target, changes)
    for key, value in pairs(changes) do
        if type(value) == 'table' and type(target[key]) == 'table' then
            SharedUtils.mergeInto(target[key], value)
        else
            target[key] = value
        end
    end

    return target
end

--- Shallow copy a table.
---@param input table?
---@return table
function SharedUtils.shallowCopy(input)
    local output = {}

    for key, value in pairs(input or {}) do
        output[key] = value
    end

    return output
end

return SharedUtils