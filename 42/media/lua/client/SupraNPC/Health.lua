-- SupraNPC - avaliacao medica somente LEITURA, sem alterar dano ou cures.
-- Nao abre a interface vanilla de "Vida do Jogador" para IsoPlayer extra.
local Health = {}

local function call(obj, method, ...)
    if not obj then return nil end
    local fn
    local found = pcall(function() fn = obj[method] end)
    if not found or not fn then return nil end
    local args = {...}
    local ok, value = pcall(function() return fn(obj, unpack(args)) end)
    if ok then return value end
    return nil
end

local function number(value, low, high)
    if type(value) ~= "number" or value ~= value or
       value == math.huge or value == -math.huge then return nil end
    if low and value < low then return low end
    if high and value > high then return high end
    return value
end

local FLAGS = {
    {method = "bleeding", label = "Sangramento"},
    {method = "bitten", label = "Mordida"},
    {method = "scratched", label = "Arranhao"},
    {method = "cut", label = "Corte"},
    {method = "deepWounded", label = "Ferida profunda"},
    {method = "burned", label = "Queimadura"},
    {method = "haveGlass", label = "Estilhaco"},
    {method = "bandaged", label = "Com bandagem"}
}
local function flag(part, name)
    local methods = {
        bleeding = "bleeding", bitten = "bitten", scratched = "scratched",
        cut = "isCut", deepWounded = "isDeepWounded",
        burned = "isBurnt", haveGlass = "haveGlass", bandaged = "bandaged"
    }
    local val = call(part, methods[name])
    return val == true
end

function Health.inspect(actor, profile)
    local result = {
        id = profile and profile.id or nil,
        name = profile and (tostring(profile.firstName or "NPC") .. " " ..
            tostring(profile.lastName or "")) or "NPC",
        available = false, dead = false, health = nil,
        bleeding = false, injuries = {}, pain = nil,
        hunger = nil, thirst = nil, endurance = nil,
        reason = nil
    }
    if not actor then
        result.reason = "Entidade indisponivel"
        return result
    end
    result.dead = call(actor, "isDead") == true
    local bd = call(actor, "getBodyDamage")
    if not bd then
        result.reason = "BodyDamage indisponivel no motor"
        return result
    end
    result.available = true
    result.health = number(call(bd, "getOverallBodyHealth"), 0, 100)
    if result.health == nil then
        result.health = number(call(bd, "getHealth"), 0, 100)
    end
    local stats = call(actor, "getStats")
    result.pain = number(call(stats, "getPain"), 0, 100)
    result.hunger = number(call(stats, "getHunger"), 0, 1)
    result.thirst = number(call(stats, "getThirst"), 0, 1)
    result.endurance = number(call(stats, "getEndurance"), 0, 1)

    local parts = call(bd, "getBodyParts")
    local count = number(call(parts, "size"), 0, 100) or 0
    for i = 0, math.min(count, 40) - 1 do
        local part = call(parts, "get", i)
        if part then
            local affected = {}
            for _, info in ipairs(FLAGS) do
                if flag(part, info.method) then
                    affected[#affected + 1] = info.label
                    if info.method == "bleeding" then result.bleeding = true end
                end
            end
            if (number(call(part, "getFractureTime"), 0) or 0) > 0 then
                affected[#affected + 1] = "Fratura"
            end
            if #affected > 0 then
                local name = call(part, "getType")
                result.injuries[#result.injuries+1] = {
                    part = tostring(name or ("Parte " .. tostring(i+1))),
                    signs = table.concat(affected, ", ")
                }
            end
        end
    end
    return result
end

return Health
