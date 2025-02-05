local server_list = require "remp:server_list"
local profile =     require "remp:profile"

function is_valid_username(str)
    str = str:trim()
    local len = utf8.length(str)
    return len >= 3 and len <= 20
end

function connect(ip, port)
    if not document.username.valid then
        return
    end
    local client = session.get_entry('remp:client')
    local username = document.username.text
    if username ~= profile:get_username() then
        profile:set_username(username)
    end
    client.ip = ip
    client.port = port
    client.username = username
end

function remove_server(index)
    server_list:remove(index)
    create_server_list()
end

function create_server_list()
    document.server_list:clear()
    server_list:read()
    
    local index = 1
    while true do
        local server_info = server_list[index]
        if server_info == nil then break end
        server_info = table.copy(server_info)
        server_info.connect_func = "connect"
        server_info.remove_server_func = "remove_server(".. tostring(index) .. ")"
        document.server_list:add(gui.template("server", server_info))
        index = index + 1
    end
end

function on_open()
    create_server_list()
    local username = profile:get_username()
    if username ~= nil then
        document.username.text = username
    end
end
