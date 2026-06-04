local remp = require "remp:remp"
local packets = require "remp:packets"
local remp_client = require "remp:client"

local this = {}

function this.request_connect_info(app)
    local connect = session.get('remp:client')
    if vc.get_project_arg("remp-address") then
        connect.ip = vc.get_project_arg("remp-address")
        connect.port = tonumber(vc.get_project_arg("remp-port"))
        connect.username = vc.get_project_arg("remp-username")
            or ("user-" .. base64.encode_urlsafe(random.bytes(3)))
        connect.login_uuid = vc.get_project_arg("remp-login-uuid")
    end

    menu.page = "server_list"
    app.sleep_until(function()
        return (menu.page ~= "server_list" and menu.page ~= "add_server") or connect.ip
    end)
    session.reset('remp:client')

    if type(connect.ip) ~= "string" or type(connect.port) ~= "number" then
        return
    end
    return connect
end

local function init_connection(socket, connect)
    local conn = packets.Connection:new(socket)
    do
        local opcode, data = conn:recvWait(5)
        if opcode == nil then
            return false, "connection timed out"
        elseif opcode == remp.OPCODE_SERVER then
            conn.server_uuid = data.uuid
            conn:send(remp.OPCODE_JOIN, {
                uuid = connect.login_uuid or remp_client:get_login(data.uuid),
                username = connect.username
            })
        else
            conn:close()
            return false, "expected OPCODE_SERVER, got "..opcode
        end
    end
    return true, conn
end

function this.connect_to_server(app, connect)
    menu.page = "connecting"

    local state = "connecting"
    local status, socket = pcall(network.tcp_connect, connect.ip, connect.port, function(...)
        state = "connected"
        debug.log("connected to server")
    end)

    if not status then
        return false, socket
    end

    app.sleep_until(function() return state ~= "connecting" or not socket:is_alive() end)

    if not socket:is_alive() then
        return false, "connection refused unexpectedly"
    end
    return init_connection(socket, connect)
end

return this
