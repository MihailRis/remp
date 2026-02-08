local util = require "remp:util"
local remp = require "remp:remp"

local modchunks_file = pack.data_file("remp", "modified_chunks.json")
local modified_chunks = {}
local chunks_data = {}

local STATUS_OK = 0
local STATUS_DIRTY = 1
local STATUS_CANCELLED = 2

local server_chunks = {
    STATUS_DIRTY=STATUS_DIRTY,
    STATUS_OK=STATUS_OK,
}

function server_chunks:load()
    if file.exists(modchunks_file) then
        modified_chunks = json.parse(file.read(modchunks_file)).chunks
        for chunkid, status in pairs(modified_chunks) do
            if status == STATUS_OK then
                local cx, cz = util.chunk_from_id(chunkid)
                local data = world.get_chunk_data(cx, cz)
                if data then
                    chunks_data[chunkid] = data
                end
            else
                modified_chunks[chunkid] = nil
            end
        end
    end
end

function server_chunks:save()
    for chunkid, data in pairs(chunks_data) do
        local cx, cz = util.chunk_from_id(chunkid)
        world.save_chunk_data(cx, cz, data)
    end
    file.write(modchunks_file, json.tostring({chunks=modified_chunks}, true))
end

function server_chunks:store(cx, cz, data)
    local chunkid = util.chunk_id(cx, cz)
    chunks_data[chunkid] = data
    modified_chunks[chunkid] = STATUS_OK
end

function server_chunks:mark_dirty(cx, cz)
    modified_chunks[util.chunk_id(cx, cz)] = STATUS_DIRTY
end

function server_chunks:mark_cancelled(cx, cz)
    modified_chunks[util.chunk_id(cx, cz)] = STATUS_CANCELLED
end

function server_chunks:is_ok(chunkid)
    return modified_chunks[chunkid] == STATUS_OK
end

function server_chunks:is_cancelled(chunkid)
    return modified_chunks[chunkid] == STATUS_CANCELLED
end

function server_chunks:get_modified_chunks()
    return modified_chunks
end

function server_chunks:get_data(chunkid)
    return chunks_data[chunkid]
end

return server_chunks
