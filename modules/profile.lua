local profile = {}

local username_file = pack.shared_file("remp", "username.bin")

function profile:set_username(username)
    local temp = {}
    temp.username = username
    file.write_bytes(username_file, bjson.tobytes(temp))
end

function profile:get_username()
    if file.isfile(username_file) == false then
        return nil
    end
    local temp = bjson.frombytes(file.read_bytes(username_file))
    return temp.username
end

return profile