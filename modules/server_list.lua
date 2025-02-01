local server_list = {}

local server_list_file = pack.shared_file("remp", "server_list.bin")

function server_list:read()
	if file.isfile(server_list_file) == false then
		return
	end
	local temp = bjson.frombytes(file.read_bytes(server_list_file))
	for k, v in pairs(temp) do
		server_list[tonumber(k)] = v
	end
end

function server_list:write()
	local temp = {}
	for k, v in pairs(server_list) do
		if type(v) ~= "function" then
			temp[tostring(k)] = v
		end
	end
	file.write_bytes(server_list_file, bjson.tobytes(temp))
end

function server_list:add(name, ip, port)
	local server_info = {}
	server_info.name = name
	server_info.ip = ip
	server_info.port = port
	table.insert(server_list, server_info)
	server_list:write()
end

function server_list:remove(index)
	table.remove(server_list, index)
	server_list:write()
end

return server_list