local rout = include 'lib/nest/routines/grid'

local Grid = {}

local input_contained = function(s, inargs)
    local contained = { x = false, y = false }
    local axis_size = { x = nil, y = nil }

    local args = { x = inargs[1], y = inargs[2] }

    for i,v in ipairs{"x", "y"} do
        if type(s.p_[v]) == "table" then
            if #s.p_[v] == 1 then
                s[v] = s.p_[v][1]
                if s.p_[v] == args[v] then
                    contained[v] = true
                end
            elseif #s.p_[v] == 2 then
                if  s.p_[v][1] <= args[v] and args[v] <= s.p_[v][2] then
                    contained[v] = true
                end
                axis_size[v] = s.p_[v][2] - s.p_[v][1] + 1
            end
        else
            if s.p_[v] == args[v] then
                contained[v] = true
            end
        end
    end

    return contained.x and contained.y, axis_size
end

local function filter_input(s, args)
    local contained, axis_size = input_contained(s, args)

    if contained then
        if axis_size.x == nil and axis_size.y == nil then
            return "point", nil, { nil, nil, args[3] }
        elseif axis_size.x ~= nil and axis_size.y ~= nil then
            return "plane", axis_size, { args[1] - s.p_.x[1] + 1, s.p_.y[2] - args[2] + 1, args[3] }
        else
            if axis_size.x ~= nil then
                return "line", axis_size.x, { args[1] - s.p_.x[1] + 1, nil, args[3] }
            elseif axis_size.y ~= nil then
                return  "line", axis_size.y, { s.p_.y[2] - args[2] + 1, nil, args[3] }
            end
        end
    else return nil end
end


Grid.define = function(def) 
    def.name = def.name or ''
    def.init = def.init or function(format, data) end
    def.default_props = def.default_props or {}
    def.handlers = def.handlers or {}
    def.input_filter = def.input_filter or filter_input

    local grid_default_props = {
        x = 1, y = 1, lvl = 15,
    }

    return function(state)
        if not nest.loop.started.grid then
            state = state or 0

            local default_props = def.default_props
            setmetatable(default_props, { __index = grid_default_props })

            local data = { 
                value = state,
                clock = true,
            } 

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

            return function(props)
                if nest.loop.device == 'grid' then

                    setmetatable(props, { __index = default_props })

                    -- proxy for props & data for backwards compatability with routines/
                    local s = setmetatable({
                        p_ = setmetatable({}, {
                            __index = props,
                            __call = function(_, k, ...)
                                if type(props[k]) == 'function' then
                                    return props[k](data, ...)
                                else
                                    return props[k]
                                end
                            end
                        }),
                        replace = function(s, k, v)
                            data[k] = v
                        end
                    }, {
                        __index = data,
                        __newindex = data,
                    })

                    --map "v" to wherever value should be coming from
                    if props.state and props.state[1] then 
                        props.v = props.state[1]
                    else
                        props.v = data.value
                    end

                    if nest.loop.mode == 'input' then

                        local fmt, size, hargs = def.input_filter(s, nest.args.grid)

                        if fmt then
                            if fmt ~= data.format then
                                data.format = fmt
                                def.init(data.format, size, data)
                            end
            
                            local x, y, z = hargs[1], hargs[2], hargs[3]
                            nest.handle.grid(
                                handlers.input[data.format], 
                                props, 
                                data, 
                                { s, x, y, z }, 
                                handlers.change[data.format]
                            )
                        end
                    elseif nest.loop.mode == 'redraw' then
                        nest.redraw.grid(
                            handlers.redraw[data.format], 
                            s, 
                            nest.device.grid, 
                            props.v
                        )
                    else nest.render_error('Grid.'..def.name..'()') end
                end
            end
        else nest.constructor_error('Grid.'..def.name..'()') end
    end
end

local function minit(format, size) 
    --TODO
end

local binaryvals = function(format, size, o)
    o.list = {}

    o.v = minit(format, size)
    o.held = minit(format, size)
    o.tdown = minit(format, size)
    o.tlast = minit(format, size)
    o.theld = minit(format, size)
    o.vinit = minit(format, size)
    o.lvl_frame = minit(format, size)
    o.lvl_clock = minit(format, size)
    o.blank = {}
end

Grid.momentary = Grid.define{
    name = 'momentary',
    default_props = {
        edge = 'both',
    },
    init = function(format, size, data) 
        binaryvals(format, size, data)
    end,
    handlers = rout.momentary
}

return Grid
