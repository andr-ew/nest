local Grid = {}

local function filter_input(p, priv, init, args)
    --TODO: filter input + initialize private data & value based on props x & y + return custom handler args
    
    return contained, x, y, z
end

Grid.define = function(def) 
    def.name = def.name or ''
    def.init = def.init or function(format, priv) end
    def.default_props = def.default_props or {}
    def.handlers = def.handlers or {}

    local grid_default_props = {
        x = 1, y = 1, lvl = 15,
    }

    return function(state)
        if not nest.rendering.grid then
            state = state or 0

            local default_p = def.default_props
            setmetatable(default_p, { __index = grid_default_props })

            local priv = { 
                value = state,
                clock = true,
            } 
            setmetatable(priv, { __index = default_p })

            local init = def.init

            local handlers_blank = {
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
            local handlers = def.handlers
            setmetatable(handlers, { __index = handlers_blank })

            return function(p)
                setmetatable(p, { __index = priv })
                
                if nest.mode_input then

                    local contained, x, y, z = filter_input(p, priv, init, nest.args.grid)

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
                elseif nest.mode_redraw then
                    nest.redraw.grid(handlers.redraw[priv.format], p, priv)
                else nest.render_error('Grid.toggle()') end
            end
        else nest.constructor_error('Grid.toggle()') end
    end
end

return Grid
