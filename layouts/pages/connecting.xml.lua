local frameid = 0

function on_open()
    document.root:setInterval(500, function()
        local dots = "" 
        for i=0,frameid-1 do
            dots = dots.."."
        end
        document.label.text = "Connecting"..dots
        frameid = (frameid + 1) % 4
    end)
end
