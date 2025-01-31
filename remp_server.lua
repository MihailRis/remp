local DEFAULTS_STR = [[
# REMP server configuration
port=60019
world_name="server"
world_seed="2025"
generator="core:default"
max_client_load=1e4
content=["base"]
]]
local DEFAULTS = toml.parse(DEFAULTS_STR)

-- Loading configuration
local config

local config_file = pack.shared_file("remp", "config.toml")
if not file.exists(config_file) then
    file.write(config_file, DEFAULTS_STR)
    print("\nConfiguration generated. See "..string.escape(config_file).."\n")
    return
else
    local readconfig = toml.parse(file.read(config_file))
    config = setmetatable(readconfig, {__index=DEFAULTS})
end

-- Preparing the world
if world.exists(config.world_name) then
    app.open_world(config.world_name)
else
    table.insert(config.content, "remp")
    app.reconfig_packs(config.content, {})
    app.new_world(config.world_name, config.world_seed, config.generator)
    app.save_world()
end

local remp     = require "remp:remp"
local util     = require "remp:util"
local packets  = require "remp:packets"
local accounts = require "remp:accounts"
local chunks   = require "remp:server_chunks"

chunks:load()
accounts:load()
accounts:save()

local Connection = packets.Connection

local clients = {}

events.on("remp:save_world", function ()
    chunks:save()
    accounts:save()
end)

local function broadcast(opcode, data, ignore_uuid)
    for _, client in ipairs(clients) do
        if client.uuid ~= ignore_uuid then
            client:send(opcode, data)
        end
    end
end

local function get_player_name(pid)
    return gui.escape_markup("md", player.get_name(pid))
end

console.add_command(
    "chat text:str",
    "Send chat message",
    function (args, kwargs)
        broadcast(remp.OPCODE_CHAT, {
            string.format("**%s:** %s[#      ]", 
                get_player_name(console.get("player")), args[1]
            )
        })
    end
)

local function create_account()
    local pid = player.create("")
    player.set_loading_chunks(pid, false)
    return accounts:create(pid)
end

local function create_player_data(client)
    return {
        client.pid,
        true, -- spawn
        client.full_username,
        {player.get_pos(client.pid)},
        {player.get_rot(client.pid)}
    }
end

local function random_client(except_uuid)
    if #clients == 0 or (#clients == 1 and clients[1].uuid == except_uuid) then
        return nil
    end
    while true do
        local client = clients[math.random(1, #clients)]
        if client.uuid ~= except_uuid then
            return client
        end
    end
end

local function request_chunk(client, chunkid, x, z)
    client:send(remp.OPCODE_REQUEST_CHUNK, {x, z})
    for i=1,20 do
        coroutine.yield()
        -- client have been disconnected
        if not table.has(clients, client) or chunks:is_ok() or chunks:is_cancelled() then
            break
        end
    end
end

local function send_requests(conn, sent, requests, client_supplier)
    for chunkid, status in pairs(chunks:get_modified_chunks()) do
        if table.has(sent, chunkid) then
            goto continue
        end
        local x, z = util.chunk_from_id(chunkid)
        local data = chunks:get_data(chunkid)
        if status == chunks.STATUS_OK then
            conn:send(remp.OPCODE_CHUNK, {x, z, data})
            table.insert(sent, chunkid)
        else
            local client = client_supplier(conn.uuid)
            if client then
                local co = coroutine.create(request_chunk)
                coroutine.resume(co, client, chunkid, x, z)
                table.insert(requests, {chunkid, co})
            else
                if data ~= nil then
                    conn:send(remp.OPCODE_CHUNK, {x, z, data})
                end
            end
        end
        ::continue::
    end
end

local function wait_requests(requests)
    while #requests > 0 do
        coroutine.yield()
        local remaining = {}
        for _, request in ipairs(requests) do
            local chunkid, co = unpack(request)
            if coroutine.status(co) ~= "dead" then
                local success, err = coroutine.resume(co)
                if not success then
                    debug.error("chunk request error: "..err)
                else
                    table.insert(remaining, {chunkid, co})
                end
            end
            ::continue::
        end
        requests = remaining
    end
end

local function send_initial_world_data(conn)
    conn:send(remp.OPCODE_WORLD, {
        world.get_generator(),
        world.get_seed(),
        pack.get_installed(),
        conn.pid,
        conn.uuid,
        world.get_day_time()
    })
    local total_required = table.count_pairs(chunks:get_modified_chunks())
    local sent = {}
    local requests = {}
    local max_attemps = 5
    local attempts = max_attemps
    while attempts > 0 do
        if #sent == total_required then
            debug.log(string.format("all %s chunks are sent", total_required))
            break
        end
        send_requests(conn, sent, requests, random_client)
        debug.log(string.format(
            "attempt #%s -> sent %s chunk requests",
            (max_attemps-attempts), #requests))

        wait_requests(requests)
        attempts = attempts - 1
    end

    if #sent < total_required then
        send_requests(conn, sent, requests, function() return end)
        debug.log(string.format(
            "sending rest saved chunks -> sent %s chunk requests", #requests))
        wait_requests(requests)
    end

    local players_data = {}
    for _, client in ipairs(clients) do
        if client.pid and client.full_username then
            table.insert(players_data, create_player_data(client))
        end
    end
    conn:send(remp.OPCODE_PLAYERS, players_data)
end

local function log_in(conn)
    if conn.uuid == nil then
        conn.uuid = create_account()
    elseif not accounts:exists(conn.uuid) then
        debug.log("attempt to join as non-existing account "..conn.uuid)
        conn:disconnect(remp.ERR_NO_ACCOUNT)
        return false
    elseif accounts:is_banned(conn.uuid) then
        debug.log("attempt to join as banned account "..conn.uuid)
        conn:disconnect(remp.ERR_BANNED)
        return false
    end
    for _, client in ipairs(clients) do
        if client.uuid == conn.uuid and client.addressStr ~= conn.addressStr then
            debug.log("attempt to join as already logged-in user "..conn.uuid)
            conn:disconnect(remp.ERR_ALREADY_ONLINE)
            return false
        end
    end
    conn.pid = accounts:on_login(conn.uuid, conn.username)
    conn.full_username = string.format("%s[%s]", conn.username, conn.pid)
    send_initial_world_data(conn)
    broadcast(remp.OPCODE_CHAT, {"**"..get_player_name(conn.pid).." joined the game**"})
    broadcast(remp.OPCODE_PLAYERS, {create_player_data(conn)}, conn.uuid)
    return true
end

local function client_world_loop(conn)
    local max_packets_per_tick = 20
    while conn:isAlive() do
        if (conn:available() or 0) > config.max_client_load then
            conn:disconnect(remp.ERR_OVERLOAD)
            break
        end
        for i=1,max_packets_per_tick do
            local opcode, object = conn:recv()
            if not opcode then
                break
            end
            if opcode == remp.OPCODE_CHAT then
                local full_msg = "**"..conn.full_username..":** "..object[1]
                broadcast(remp.OPCODE_CHAT, {full_msg})
            elseif opcode == remp.OPCODE_LEAVE then
                conn:close()
                return
            elseif opcode == remp.OPCODE_MOVEMENT then
                player.set_pos(conn.pid, unpack(object[1]))
                player.set_rot(conn.pid, unpack(object[2]))
                broadcast(remp.OPCODE_MOVEMENT, {
                    conn.pid, object[1], object[2],
                }, conn.uuid)
            elseif opcode == remp.OPCODE_BLOCK_EVENT then
                local x, z = object[1], object[3]
                local cx, cz = util.get_chunk(x, z)
                chunks:mark_dirty(cx, cz)
                broadcast(remp.OPCODE_BLOCK_EVENT, {
                    conn.pid, unpack(object),
                }, conn.uuid)
            elseif opcode == remp.OPCODE_CHUNK then
                local cx, cz = object[1], object[2]
                if object[3] then
                    chunks:store(cx, cz, object[3])
                else
                    chunks:mark_cancelled(cx, cz)
                end
            elseif opcode == remp.OPCODE_COMMAND then
                -- local text = object[1]
                -- console.set("player", conn.pid)
                -- local status, result = pcall(console.execute, text)
                -- if result then
                --     conn:send(remp.OPCODE_CHAT, {result})
                -- end
            end
        end
        coroutine.yield()
    end
end

local function on_client_disconnect(conn)
    accounts:on_logout(conn.uuid)
    broadcast(remp.OPCODE_CHAT, {
        "**"..get_player_name(conn.pid).." left the game**"
    })
    broadcast(remp.OPCODE_PLAYERS, {{conn.pid, false}}, conn.uuid)
end

-- Open a server
local server = network.tcp_open(config.port, function (socket)
    local conn = Connection:new(socket)
    local client_ip, _ = socket:get_address()
    if accounts:is_ip_banned(client_ip) then
        debug.log("attempt to join from banned IP "..client_ip)
        conn:close()
        return
    end
    conn:send(remp.OPCODE_SERVER, {
        uuid=accounts.server_uuid
    })
    conn.co = coroutine.create(function()
        local opcode, object = conn:recvWait()
        if opcode ~= remp.OPCODE_JOIN then conn:close() return end

        conn.uuid = object.uuid
        conn.username = object.username
        if not log_in(conn) then
            return
        end
        player.set_name(conn.pid, conn.full_username)
        client_world_loop(conn)
    end)
    table.insert(clients, conn)
end)

local dead = {}
-- Main loop
while true do -- stop the server with SIGTERM (kill or systemctl stop)
    for i, client in ipairs(clients) do
        local success, err = coroutine.resume(client.co)
        if not success then
            debug.error("client coroutine error: "..err)
            client:disconnect(remp.ERR_INTERNAL)
            table.insert(dead, i)
        end
        if not client:isAlive() then
            table.insert(dead, i)
            goto continue
        end
        ::continue::
    end
    for i = #dead, 1, -1 do
        local index = dead[i]
        local client = clients[index]
        table.remove(clients, index)
        if client and client.full_username then
            on_client_disconnect(client)
        end
        -- TODO: autosave
        --if #clients == 0 then
            app.save_world()
        --end
    end
    if #dead > 0 then
        dead = {}
    end
    app.tick()
end

-- Close all clients
for _, client in ipairs(clients) do
    client:close()
end

world.close(true)
