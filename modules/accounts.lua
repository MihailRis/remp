local util = require "remp:util"

local accounts = {
    server_uuid = util.generate_uuid(),
    repo = {},
    banned_ips = {}
}

function accounts:create(pid)
    local uuid = util.generate_uuid()
    local account = {
        uuid=uuid,
        pid=pid,
        banned=false,
        journal={},
    }
    self.repo[uuid] = account
    return uuid
end

function accounts:load()
    local repo_file = pack.data_file("remp", "accounts.json")
    if not file.exists(repo_file) then
        return
    end
    local data = json.parse(file.read(repo_file))
    self.server_uuid = data.server_uuid
    self.repo = data.accounts
    self.banned_ips = data.banned_ips
    debug.log(string.format("loaded %s account(s)", #self.repo))
end

function accounts:save()
    local repo_file = pack.data_file("remp", "accounts.json")
    file.write(repo_file, json.tostring({
        server_uuid=self.server_uuid,
        accounts=self.repo,
        banned_ips=self.banned_ips,
    }, true))
end

function accounts:on_login(uuid, username)
    local acc = accounts.repo[uuid]
    local pid = acc.pid
    player.set_suspended(pid, false)
    
    if not acc.journal then
        acc.journal = {}
    end
    table.insert(acc.journal, {
        username, os.date("!%Y-%m-%dT%TZ")
    })
    return pid
end

function accounts:on_logout(uuid)
    local acc = accounts.repo[uuid]
    local pid = acc.pid
    player.set_suspended(pid, true)
end

function accounts:exists(uuid)
    return accounts.repo[uuid] ~= nil
end

function accounts:is_banned(uuid)
    local acc = accounts[uuid]
    if acc == nil then
        return false
    end
    return acc.banned
end

function accounts:is_ip_banned(address)
    return table.has(self.banned_ips, address)
end

return accounts
