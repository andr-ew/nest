nest = {
    loop = {
        device = nil,
        mode = nil,
        started = {}
    },
    handle_input = {},
    handle_redraw = {},
    device = {},
    dirty = {
        grid = true
    },
    args = {},
    observers = {},
}

nest.constructor_error = function(name)
    print('constructor error', name)
end
nest.render_error = function(name)
    print('render error', name)
end

function nest.handle_input.device(device, handler, props, data, hargs, on_update)
    local aargs = table.pack(handler(table.unpack(hargs)))
    
    local function action()
        local v = props.action and props.action(table.unpack(aargs)) or aargs[1]

        nest.dirty[device] = true
        
        if(props.state and props.state[2]) then
            --TODO: throw helpful error if state[2] is not a function
            aargs[1] = v
            props.state[2](table.unpack(aargs))
        else
            data.value = v
        end
        
        if(on_update) then on_update(props, data, v, hargs) end
    end

    if aargs and aargs[1] then
        --TODO: pass handler, props, hargs, on_update to active observers
        
        if props.action and data.clock then
            if data.clock_id then clock.cancel(data.clock_id) end
            data.clock_id = clock.run(action)
        else
            action()
        end
    end
end

return nest
