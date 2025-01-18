local client = require "client"
local util   = require "util"

local modified_chunks = {}

local function modify_chunk_at_block(x, z)
    local chunkid = util.chunk_id(util.get_chunk(x, z))
    if not table.has(modified_chunks, chunkid) then
        table.insert(modified_chunks, chunkid)
    end
end

function on_block_broken(id, x, y, z, pid)
    if client:is_init() then
        if pid == client.pid then
            client:block_event(x, y, z, 0)
        end
        modify_chunk_at_block(x, z)
    end
end

function on_block_placed(id, x, y, z, pid)
    if client:is_init() then
        if pid == client.pid then
            client:block_event(x, y, z, 1, id, block.get_states(x, y, z))
        end
        modify_chunk_at_block(x, z)
    end
end

function on_block_interact(id, x, y, z, pid)
    if client:is_init() then
        if pid == client.pid then
            client:block_event(x, y, z, 2, id, pid)
            modify_chunk_at_block(x, z)
        end
    end
end

function on_chunk_remove(x, z)
    local chunkid = util.chunk_id(x, z)
    if table.has(modified_chunks, chunkid) then
        client:send_chunk(x, z, world.get_chunk_data(x, z))
    end
end

function on_world_quit()
    for i, chunkid in ipairs(modified_chunks) do
        local x, z = util.chunk_from_id(chunkid)
        client:send_chunk(x, z, world.get_chunk_data(x, z))
    end
end
