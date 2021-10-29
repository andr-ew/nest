nest = {
    mode = nil,
    handle = {},
    redraw = {},
    devices = {},
    dirty = {},
}

local function doaction(device, props, priv, aargs, on_update)
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
        
    if props.action and priv.clock then
        if priv.clock_id then clock.cancel(priv.clock_id) end
        priv.clock_id = clock.run(action)
    else
        action()
    end
end

nest.handle.grid = function(handler, props, priv, hargs, on_update)
    local aargs = table.pack(handler(props, table.unpack(hargs)))

    if aargs and aargs[1] then
        --TODO: pass handler, props, hargs, on_update to active observers
        
        doaction('grid', props, priv, aargs, on_update)
    end
end

nest.redraw.grid = function(handler, props, priv)
    handler(props, nest.grid.device, props.state and props.state[1] or priv.value)
end

return nest

-- test

Grid = {}

local grid_default_p = {
    x = 1, y = 1, lvl = 15,
}

--TODO: turn this into Grid.define{} which takes args (name, init, default_props, handlers) and returns a component constructor
Grid.toggle = function(state)
    if not nest.rendering.grid then
        state = state or 0

        local default_p = {
            edge = 'rising', min = -math.huge, max = math.huge,
        }
        setmetatable(default_p, { __index = grid_default_p })

        local priv = { 
            value = state,
            clock = true,
        } 
        setmetatable(priv, { __index = default_p })

        local init = function(format, priv)
            priv.toglist = {},
            priv.ttog = {},
        end

        local handlers = {
            input = {
                point = function(s, x, y, z) end,
                line = function(s, x, y, z) end,
                plane = function(s, x, y, z) end,
            },
            change = {
                point = function(s, v) end,
                line_x = function(s, v) end,
                line_y = function(s, v) end,
                plane = function(s, v) end,
            },
            redraw = {
                point = function(s, g, v) end,
                line_x = function(s, g, v) end,
                line_y = function(s, g, v) end,
                plane = function(s, g, v) end,
            }
        }

        return function(p)
            setmetatable(p, { __index = priv })
            
            if nest.mode = 'input' then

                --filter input + initialize private data & value based on props x & y + return custom handler args
                local contained, x, y, z = grid_filter_in(p, priv, init, nest.args.grid)

                if contained then
                    
                    --map "v" to wherever value should be coming from
                    if props.state and props.state[1] then 
                        props.v = props.state[1]
                    else
                        props.v = priv.value
                    end
    
                    nest.handle.grid(
                        handlers.input[priv.format], 
                        p, priv, { x, y, z }, 
                        handlers.change[priv.format]
                    )
                end
            elseif nest.mode = 'output' then
                nest.redraw.grid(handlers.redraw[priv.format], p, priv)
            else nest.render_error('Grid.toggle()') end
        end
    else nest.constructor_error('Grid.toggle()') end
end
