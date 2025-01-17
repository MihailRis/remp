app.config_packs({"remp"})
app.load_content()

local remp    = require "remp:remp"
local packets = require "remp:packets"

local connect = session.get_entry('remp:client')
menu.page = "connect"
app.sleep_until(function() return menu.page ~= "connect" or connect.ip end)
session.reset_entry('remp:client')

if not connect.ip then
    app.reset_content()
    return
end

menu.page = "connecting"

local state = "connecting"
local status, socket = pcall(network.tcp_connect, connect.ip, connect.port, function(conn)
    state = "connected"
    print("Connected to server")
end)
if not status then
    debug.error(socket)
    app.reset_content()
    gui.alert("Connection error: "..socket, function()
        menu.page = "main"
    end)
    return
end

app.sleep_until(function() return state ~= "connecting" or not socket:is_alive() end)

if not socket:is_alive() then
    app.reset_content()
    gui.alert("Connection refused", function()
        menu.page = "main"
    end)
    return
end

local remp_client = require "remp:client"
remp_client:init()

local server_uuid
local local_player

local conn = packets.Connection:new(socket)
do
    local opcode, data = conn:recvWait()
    if opcode == remp.OPCODE_SERVER then
        server_uuid = data.uuid
        conn:send(remp.OPCODE_JOIN, {
            uuid=remp_client:get_login(data.uuid),
            username=connect.username
        })
    else
        debug.error("expected OPCODE_SERVER, got "..opcode)
        conn:close()
    end
end

local function perform_players(data)
    for _, pdata in ipairs(data) do
        local pid = pdata[1]
        if pdata[2] then
            player.create("", pid)
            player.set_name(pid, pdata[3])
            player.set_pos(pid, unpack(pdata[4]))
            player.set_rot(pid, unpack(pdata[5]))
            player.set_loading_chunks(pid, false)
        else
            player.delete(pid)
        end
    end
end

while socket:is_alive() do
    local opcode, data = conn:recv()
    if not opcode then
        goto continue
    end
    if opcode == remp.OPCODE_WORLD then
        local generator, seed, packs, pid, uuid = unpack(data)
        remp_client:save_login(server_uuid, uuid)

        conn.pid = pid
        local_player = pid

        app.config_packs(packs)
        app.load_content()

        app.new_world("", tostring(seed), generator, pid)
        player.set_loading_chunks(pid, false)
    elseif opcode == remp.OPCODE_PLAYERS then
        perform_players(data)
        player.set_loading_chunks(local_player, true)
        break
    else
        debug.warning(
            string.format("unhandled packet %s %s", opcode, json.tostring(data)))
    end
    ::continue::
    app.tick()
end

if not world.is_open() then
    app.reset_content()
    gui.alert("Connection refused", function()
        menu.page = "main"
    end)
    return
end

gui_util.add_page_dispatcher(function(name, args)
    if name == "pause" then
        name = "client_pause"
    end
    return name, args
end)

-- modules will reset on world load
remp_client = require "remp:client"
remp_client:init(conn)

local pid = hud.get_player()

local function world_loop()
    local tickid = 0
    while true do
        sleep(1.0 / 20.0)
        rules.set("allow-fast-interaction", false)
        tickid = tickid + 1
        if tickid % 2 == 0 then
            remp_client:movement(pid)
        end
    end
end

local world_co = coroutine.create(world_loop)

while socket:is_alive() do
    app.tick()
    if not world.is_open() then
        remp_client:leave()
        conn:close()
        break
    end

    local opcode = true
    local data

    while opcode do 
        opcode, data = conn:recv()
        if opcode == remp.OPCODE_CHAT then
            console.log(data[1])
        elseif opcode == remp.OPCODE_DISCONNECT then
            if world.is_open() then
                hud.pause()
            end
            gui.alert(gui.str("Connection refused: "..data[1]), function()
                if world.is_open() then
                    app.close_world(false)
                else
                    menu:reset()
                    menu.page = "main"
                end
            end)
            return
        elseif opcode == remp.OPCODE_MOVEMENT then
            local pid = data[1]
            player.set_pos(pid, unpack(data[2]))
            player.set_rot(pid, unpack(data[3]))
            local entity = entities.get(player.get_entity(pid))
            if entity then
                entity.rigidbody:set_enabled(false)
                entity.skeleton:set_interpolated(true)
            end
        elseif opcode == remp.OPCODE_PLAYERS then
            perform_players(data)
        elseif opcode == remp.OPCODE_BLOCK_EVENT then
            local pid = data[1]
            local x, y, z = data[2], data[3], data[4]
            local event = data[5]
            local id = data[6]
            local states = data[7]
            if event == 0 then
                block.destruct(x, y, z, pid)
            elseif event == 1 then
                block.place(x, y, z, id, states, pid)
            elseif event == 2 then
                events.emit(block.name(id)..".interact", x, y, z, pid)
            end
        elseif opcode then
            debug.warning(
                string.format("unhandled packet %s %s", opcode, json.tostring(data)))
        end
    end
    if world_co then
        local success, err = coroutine.resume(world_co)
        if not success then
            debug.error("error in the world coroutine: "..err)
            world_co = nil
            gui.alert(err, function()
                remp_client:leave()
            end)
        end
    end
end

gui.alert(gui.str("Connection refused"), function()
    if world.is_open() then
        app.close_world(false)
    else
        menu:reset()
        menu.page = "main" 
    end
end)
