local client = require "remp:client"

function on_hud_open()
    debug.log("local player is "..tostring(hud.get_player()))
    console.add_command(
        "chat text:str",
        "Send chat message",
        function (args, kwargs)
            client:chat(args[1])
        end
    )
    hud.set_allow_pause(false)
end
