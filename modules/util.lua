local util = {}

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
