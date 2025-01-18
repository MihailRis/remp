local util = {}

function util.generate_uuid()
    math.randomseed(os.clock() * 1000)
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local result = {string.gsub(template, '[xy]', function (c)
        math.randomseed(os.clock() * (1 + math.random()) * 1000)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)}
    return result[1]
end

function util.get_chunk(x, z)
    return math.floor(x / 16.0), math.floor(z / 16.0)
end

function util.chunk_id(x, z)
    return string.format("%s:%s", x, z)
end

function util.chunk_from_id(id)
    local x, z = id:match("^([-+]?%d+):([-+]?%d+)$")
    return tonumber(x), tonumber(z)
end

return util
