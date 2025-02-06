local server_list = require "remp:server_list"

function is_valid_ip(ip_str)
    local ip_parts = string.split(ip_str, '.')
    if ip_parts == nil or #ip_parts ~= 4 then
        return false
    end

    for _, part in pairs(ip_parts) do
        if not string.match(part, "^%d+$") then
            return false
        end
        if string.len(part) > 1 and part:sub(1, 1) == '0' then
            return false
        end
        local num = tonumber(part)
        if num < 0 or num > 255 then
            return false
        end
    end

    return true
end

function is_valid_domain(domain)
    if #domain > 253 then
        return false
    end

    local domain_parts = string.split(domain, '.')
    if #domain_parts < 1 then
        return false
    end
    if domain_parts == nil then
        domain_parts = domain
    end

    for _, part in pairs(domain_parts) do
        if #part < 1 or #part > 63 then
            return false
        end
        if part[1] == '-' or part[#part] == '-' then
            return false
        end
        if not (string.match(part, "[%w-]+") == part) then
            return false
        end
    end
    
    return true
end

function is_valid_address_port(str)
    local ip_port = string.split(str, ':')
    if ip_port == nil or #ip_port ~= 2 then
        return false
    end
    local ip = ip_port[1]
    local port_str = ip_port[2]

    if not is_valid_ip(ip) and not is_valid_domain(ip) then
        return false
    end

    if not port_str:match("^%d+$") then
        return false
    end
    if string.len(port_str) > 1 and port_str:sub(1, 1) == '0' then
        return false
    end
    local port = tonumber(port_str)
    if port < 1 or port > 65535 then
        return false
    end

    local index = 1
    while true do
        local server_info = server_list[index]
        if server_info == nil then break end
        if server_info.ip == ip and server_info.port == port_str then
            return false
        end
        index = index + 1
    end
    return true
end

local function parse_address(address_string)
    return address_string:match("([^:]+):(%d+)")
end

function add_server()
    if not document.ip.valid then
        return
    end
    local name = document.server_name.text
    local address, port = parse_address(document.ip.text)

    server_list:add(name, address, port)
    menu:back()
end