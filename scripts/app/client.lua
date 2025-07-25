app.config_packs({"remp"})
app.load_content()

local remp    = require "remp:remp"
local packets = require "remp:packets"

local connect = session.get_entry('remp:client')
menu.page = "server_list"
app.sleep_until(function() return (menu.page ~= "server_list" and menu.page ~= "add_server") or connect.ip end)
session.reset_entry('remp:client')

if not connect.ip then
    app.reset_content()
    return
end

local function leave_to_menu()
    if world.is_open() then
        app.close_world(false)
    else
        app.reset_content()
        menu:reset()
        menu.page = "main" 
    end
end

menu.page = "connecting"

local state = "connecting"
local status, socket = pcall(network.tcp_connect, connect.ip, connect.port, function(conn)
    state = "connected"
    print("Connected to server")
end)
if not status then
    debug.error(socket)
    gui.alert("Connection error: "..socket, leave_to_menu)
    return
end

app.sleep_until(function() return state ~= "connecting" or not socket:is_alive() end)

if not socket:is_alive() then
    gui.alert("Connection refused", leave_to_menu)
    return
end

local util        = require "remp:util"
local remp_client = require "remp:client"
remp_client:init()

local server_uuid
local local_player

local conn = packets.Connection:new(socket)
do
    local opcode, data = conn:recvWait(5)
    if opcode == nil then
        return gui.alert("Connection timed out", leave_to_menu)
    elseif opcode == remp.OPCODE_SERVER then
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

            local x, y, z = unpack(pdata[4])
            if not (math.abs(x) < 0.001 and 
                    math.abs(z) < 0.001 and math.abs(y-100) < 0.001) then
                player.set_pos(pid, x, y, z)
            end
            player.set_rot(pid, unpack(pdata[5]))
            player.set_loading_chunks(pid, false)
        else
            player.delete(pid)
        end
    end
end

local chunks_data = {}
while socket:is_alive() do
    local opcode, data = conn:recvWait(5)
    if not opcode then
        return gui.alert("Connection refused", leave_to_menu)
    end
    if opcode == remp.OPCODE_WORLD then
        local generator, seed, packs, pid, uuid, daytime = unpack(data)
        remp_client:save_login(server_uuid, uuid)

        conn.pid = pid
        local_player = pid

        app.reset_content()
        app.config_packs(packs)
        app.load_content()

        app.new_world("", tostring(seed), generator, pid)
        player.set_loading_chunks(pid, false)
        time.post_runnable(function ()
            world.set_day_time(daytime)
        end)
    elseif opcode == remp.OPCODE_CHUNK then
        table.insert(chunks_data, data)
        remp_client:mark_chunk_loaded(util.get_chunk(data[1], data[2]))
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
    gui.alert("Connection refused", leave_to_menu)
    return
end

gui_util.add_page_dispatcher(function(name, args)
    if name == "pause" then
        name = "client_pause"
    end
    return name, args
end)

-- modules will reset on world load
util  = require "remp:util"
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
local exited = false

while socket:is_alive() do
    app.tick()
    if not world.is_open() then
        remp_client:leave()
        conn:close()
        exited = true
        break
    end

    local new_chunks_data = {}
    if #chunks_data > 0 then
        for i, chunk_data_entry in ipairs(chunks_data) do
            local success, result = pcall(world.set_chunk_data, unpack(chunk_data_entry))
            if success then
                if not result then
                    table.insert(new_chunks_data, chunk_data_entry)
                end
            else
                debug.error("error in set_chunk_data: "..result)
            end
        end
    end
    chunks_data = new_chunks_data

    local opcode = true
    local data

    while opcode do 
        opcode, data = conn:recv()
        if opcode == remp.OPCODE_CHAT then
            console.chat(data[1])
        elseif opcode == remp.OPCODE_DISCONNECT then
            if world.is_open() then
                hud.pause()
            end
            gui.alert(gui.str("Connection refused: "..data[1]), leave_to_menu)
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
        elseif opcode == remp.OPCODE_CHUNK then
            local cx, cz = data[1], data[2]
            world.set_chunk_data(cx, cz, data[3])
        elseif opcode == remp.OPCODE_REQUEST_CHUNK then
            local cx, cz = data[1], data[2]
            if remp_client:has_chunk(cx, cz) then
                local chunk_data = world.get_chunk_data(cx, cz)
                remp_client:send_chunk(cx, cz, chunk_data)
            else
                remp_client:send_chunk(cx, cz, nil)
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

if exited then
    leave_to_menu()
else
    gui.alert(gui.str("Connection refused"), leave_to_menu)
end
