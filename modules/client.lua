local remp = require "remp:remp"
local util = require "remp:util"

local client = {
    logins = {},
    loaded_chunks = {}
}

function client:init(conn)
    if conn then
        self.conn = conn
        self.pid = conn.pid
    end

    local logins_file = pack.shared_file("remp", "logins.json")
    if file.exists(logins_file) then
        self.logins = json.parse(file.read(logins_file))
    end
end

function client:is_init()
    return self.conn ~= nil
end

function client:save_login(server_uuid, client_uuid)
    self.logins[server_uuid] = client_uuid

    local logins_file = pack.shared_file("remp", "logins.json")
    file.write(logins_file, json.tostring(self.logins, true))
end

--- Retrieve saved client UUID for server
--- @return client UUID or nil
function client:get_login(server_uuid)
    return self.logins[server_uuid]
end

function client:chat(message)
    self.conn:send(remp.OPCODE_CHAT, {message})
end

function client:submit_command(text)
    self.conn:send(remp.OPCODE_COMMAND, {text})
end

function client:leave()
    self.conn:send(remp.OPCODE_LEAVE, {})
    self.conn:close()
end

function client:movement(pid)
    self.conn:send(remp.OPCODE_MOVEMENT, {
        {player.get_pos(pid)},
        {player.get_rot(pid)},
    })
end

function client:block_event(x, y, z, eventid, id, states)
    self.conn:send(remp.OPCODE_BLOCK_EVENT, {
        x, y, z, eventid, id, states
    })
    self:mark_chunk_loaded(util.get_chunk(x, z))
end

function client:has_chunk(x, z)
    return table.has(self.loaded_chunks, util.chunk_id(x, z))
end

function client:mark_chunk_loaded(x, z)
    table.insert(self.loaded_chunks, util.chunk_id(x, z))
end

function client:send_chunk(x, z, chunk_data)
    self.conn:send(remp.OPCODE_CHUNK, {
        x, z, chunk_data
    })
end

function client:ping(id)
    self.conn:send(remp.OPCODE_PING, {id})
end

return client
