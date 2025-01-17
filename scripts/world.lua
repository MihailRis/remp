local client = require "client"

function on_world_open()
end

function on_block_broken(id, x, y, z, pid)
    if client:is_init() then
        if pid == client.pid then
            client:block_event(x, y, z, 0)
        end
    end
end

function on_block_placed(id, x, y, z, pid)
    if client:is_init() then
        if pid == client.pid then
            client:block_event(x, y, z, 1, id, block.get_states(x, y, z))
        end
    end
end

function on_block_interact(id, x, y, z, pid)
    if client:is_init() then
        if pid == client.pid then
            client:block_event(x, y, z, 2, id, pid)
        end
    end
end
