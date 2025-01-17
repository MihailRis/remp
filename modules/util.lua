local util = {}

function util.generate_uuid()
    math.randomseed(os.clock() * 1000)
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local result = {string.gsub(template, '[xy]', function (c)
        math.randomseed(os.clock() * (1 + math.random()) * 1000)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)}
    return result[1]
end

return util
