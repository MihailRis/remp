local MAX_PAYLOAD_SIZE = 0xFFFFFFFF

local remp = require "remp"

local Connection = {}
Connection.__index = Connection

function Connection:new(socket)
    local o = {
        socket=socket,
        nextsize=0,
        -- public
        addressStr=string.format("%s:%s", socket:get_address())
    }
    setmetatable(o, self)
    return o
end

local function make_message(opcode, payload)
    local data = bjson.tobytes(#payload > 0 and {_=payload} or payload, false)
    local bytes = byteutil.pack("IH", #data, opcode)
    bytes:append(data)
    -- print("<packet type="..tostring(opcode).." size="..tostring(#data)..">")
    return bytes
end

function Connection:send(opcode, payload)
    self.socket:send(make_message(opcode, payload))
end

function Connection:recv() --> opcode, payload
    if self.nextsize == 0 then
        local data
        if self.socket:available() >= 4 then
            data = self.socket:recv(4)
            if not data then
                return nil
            end
        else
            return nil
        end
        self.nextsize = byteutil.unpack("I", data)
        if self.nextsize > MAX_PAYLOAD_SIZE then
            error("payload size > MAX_PAYLOAD_SIZE (4 GB): "..self.nextsize)
        end
    end
    -- Wait for the rest of the payload
    if self.socket:available() < self.nextsize then
        return nil
    end
    local size = self.nextsize -- Payload size, not including opcode
    self.nextsize = 0
    local opcode = byteutil.unpack("H", self.socket:recv(2))
    local object = bjson.frombytes(self.socket:recv(size))
    object = object._ or object
    return opcode, object
end

function Connection:recvWait() --> opcode, payload
    while self:isAlive() do
        local opcode, object = self:recv()
        if opcode then
            return opcode, object
        end
        coroutine.yield()
    end
end

function Connection:getAddress()
    return self.socket:get_address()
end

function Connection:disconnect(reason)
    self:send(remp.OPCODE_DISCONNECT, {reason})
    self:close()
end

function Connection:close()
    self.socket:close()
end

function Connection:isAlive()
    return self.socket:is_alive()
end

function Connection:available()
    return self.socket:available()
end

return {
    Connection=Connection
}
