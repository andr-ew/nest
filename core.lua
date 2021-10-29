nest = {
    mode_input = false,
    mode_redraw = false,
    handle = {},
    redraw = {},
    device = {},
    dirty = {},
    args = {},
    observers = {},
}

nest.constructor_error = function(name)
end
nest.render_error = function(name)
end

local function handle(device, handler, props, priv, hargs, on_update)
    local aargs = table.pack(handler(props, table.unpack(hargs)))
    
    local function action()
        local v = props.action and props.action(table.unpack(aargs)) or aargs[1]

        nest.dirty[device] = true

        if(props.state and props.state[2]) then
            --TODO: throw helpful error if state[2] is not a function
            aargs[1] = v
            props.state[2](table.unpack(aargs))
        else
            priv.value = v
        end
        
        if(on_update) then on_update(v) end
    end

    if aargs and aargs[1] then
        --TODO: pass handler, props, hargs, on_update to active observers
        
        if props.action and priv.clock then
            if priv.clock_id then clock.cancel(priv.clock_id) end
            priv.clock_id = clock.run(action)
        else
            action()
        end
    end
end

-- grid (well move this to norns actually)

nest.connect_grid = function(loop, g, fps)
    local fps = fps or 30

    local redraw_grid = function()
        g:all(0)

        nest.device.grid = g
        nest.mode_redraw = true
        nest.mode_input = false
        loop()

        g:refresh()
    end

    g.key = function(x, y, z)
        nest.args.grid = { x, y, z }

        nest.device.grid = g
        nest.mode_redraw = false
        nest.mode_input = true
        loop()
    end

    while true do
        clock.sleep(1/fps)
        if nest.dirty.grid then
            redraw_grid()
        end
    end

    return redraw_grid
end

nest.handle.grid = function(...)
    handle('grid', ...)
end

nest.redraw.grid = function(handler, props, priv)
    handler(props, nest.device.grid, props.state and props.state[1] or priv.value)
end

return nest
