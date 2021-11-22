local rout = include 'lib/nest/routines/grid'

local Grid = {}

nest.connect_grid = function(loop, g, fps)
    local fps = fps or 30

    local redraw_grid = function()
        g:all(0)

        nest.args.grid = nil
        nest.device.grid = g
        nest.loop.device = 'grid'
        nest.loop.mode = 'redraw'
        loop()

        g:refresh()
    end

    g.key = function(x, y, z)
        nest.args.grid = { x, y, z }

        nest.device.grid = g
        nest.loop.device = 'grid'
        nest.loop.mode = 'input'
        loop()
    end

    nest.loop.started.grid = true
    local cl = clock.run(function()
        while true do
            clock.sleep(1/fps)
            if nest.dirty.grid then
                nest.dirty.grid = false
                redraw_grid()
            end
        end
    end)

    return redraw_grid, cl
end

nest.handle_input.grid = function(...)
    nest.handle_input.device('grid', ...)
end

nest.handle_redraw.grid = function(handler, ...)
    handler(...)
end

local input_contained = function(s, inargs)
    inargs = inargs or { -1, -1 }
    local contained = { x = false, y = false }
    local axis_size = { x = nil, y = nil }

    local args = { x = inargs[1], y = inargs[2] }

    for i,v in ipairs{"x", "y"} do
        if type(s.p_[v]) == "table" then
            if #s.p_[v] == 1 then
                s.p_[v] = s.p_[v][1]
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

local function filter(s, args)
    local contained, axis_size = input_contained(s, args)

    if axis_size.x == nil and axis_size.y == nil then
        return contained, "point", nil, args and { nil, nil, args[3] }
    elseif axis_size.x ~= nil and axis_size.y ~= nil then
        return contained, "plane", axis_size, args and { args[1] - s.p_.x[1] + 1, s.p_.y[2] - args[2] + 1, args[3] }
    else
        if axis_size.x ~= nil then
            return contained, "line_x", axis_size.x, args and { args[1] - s.p_.x[1] + 1, nil, args[3] }
        elseif axis_size.y ~= nil then
            return contained,  "line_y", axis_size.y, args and { s.p_.y[2] - args[2] + 1, nil, args[3] }
        end
    end
end

-- local function filter_redraw(s)
--     local has_axis = { x = false, y = false }

--     for i,v in ipairs{"x", "y"} do
--         if type(s.p_[v]) == "table" then
--             if #s.p_[v] == 1 then
--             elseif #s.p_[v] == 2 then
--                 has_axis[v] = true
--             end
--         end
--     end
    
--     if has_axis.x == false and has_axis.y == false then
--         return 'point'
--     elseif has_axis.x and has_axis.y then
--         return 'plane'
--     else
--         if has_axis.x then
--             return 'line_x'
--         elseif has_axis.y then
--             return 'line_y'
--         end
--     end
-- end


Grid.define = function(def) 
    def.name = def.name or ''
    def.init = def.init or function(format, data) end
    def.default_props = def.default_props or {}
    def.handlers = def.handlers or {}
    def.filter = def.filter or filter

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
            setmetatable(def.handlers, { __index = handlers_blank })

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
                        end,
                        devs = {
                            g = setmetatable({}, {
                                __index = function(t, k)
                                    if k=='dirty' then return nest.dirty.grid
                                    else return rawget(t, k) end
                                end,
                                __newindex = function(t, k, v)
                                    if k=='dirty' then
                                        nest.dirty.grid = v
                                    else rawset(t,k,v) end
                                end,
                            }),
                        },
                    }, {
                        __index = data,
                        __newindex = data,
                    })

                    local st = {}
                    if props.state and props.state[1] then 
                        st = props.state
                    else
                        st = { data.value, function(v) data.value = v end }
                    end

                    local contained, fmt, size, hargs = def.filter(s, nest.args.grid)

                    if fmt then
                        local ifmt = (fmt=='line_x' or fmt=='line_y') and 'line' or fmt

                        --(re)initialize data dynamically
                        if
                            fmt ~= data.format
                            or (
                                type(size)=='table' 
                                and (
                                    size.x ~= data.size.x or size.y ~= data.size.y
                                ) or (
                                    size ~= data.size
                                )
                            )
                        then
                            data.format = fmt
                            data.size = size

                            def.init(ifmt, size, st, data)
                        end

                        if props.state and props.state[1] then 
                            props.v = props.state[1]
                        else
                            props.v = data.value
                        end

                        if nest.loop.mode == 'input' then
                            if contained then
                                local x, y, z = hargs[1], hargs[2], hargs[3]

                                nest.handle_input.grid(
                                    def.handlers.input[ifmt], 
                                    props, 
                                    data, 
                                    { s, x, y, z }, 
                                    def.handlers.change and function(props, data, value)
                                        def.handlers.change[fmt](s, value)
                                    end
                                )
                            end
                        elseif nest.loop.mode == 'redraw' then
                            nest.handle_redraw.grid(
                                def.handlers.redraw[fmt], 
                                s, 
                                nest.device.grid, 
                                props.v
                            )
                        else nest.render_error('Grid.'..def.name..'()') end
                    end
                else nest.constructor_error('Grid.'..def.name..'()') end
            end
        end
    end
end

local function fill(format, size, n) 
    local ret = {}

    if format=='plane' then
        for x = 1,size.x do
            ret[x] = {}
            for y = 1,size.y do
                ret[x][y] = n
            end
        end
    elseif format=='line' then
        for i = 1,size do
            ret[i] = n
        end
    elseif format=='point' then 
        ret = n
    end

    return ret
end

local init_binary = function(format, size, state, o)

    --TODO: check for correct format before overwriting value table
    state[2](fill(format, size, 0))
    
    o.list = {}
    o.held = fill(format, size, 0)
    o.tdown = fill(format, size, 0)
    o.tlast = fill(format, size, 0)
    o.theld = fill(format, size, 0)
    o.vinit = fill(format, size, 0)
    o.lvl_frame = fill(format, size, 0)
    o.lvl_clock = fill(format, size, 0)
    o.blank = {}
end

Grid.momentary = Grid.define{
    name = 'momentary',
    default_props = {
        edge = 'both',
    },
    init = function(...) 
        init_binary(...)
    end,
    handlers = rout.momentary
}

Grid.toggle = Grid.define{
    name = 'toggle',
    default_props = {
        edge = 'rising',
    },
    init = function(format, size, state, data) 
        init_binary(format, size, state, data)

        data.toglist = {}
        data.ttog = fill(format, size, 0)
    end,
    handlers = rout.toggle
}

Grid.trigger = Grid.define{
    name = 'trigger',
    default_props = {
        edge = 'rising',
        lvl = {
            0,
            function(s, draw)
                draw(15)
                clock.sleep(0.1)
                draw(0)
            end
        }
    },
    init = function(format, size, state, data) 
        init_binary(format, size, state, data)

        data.triglist = {}
        data.tdelta = fill(format, size, 0)
    end,
    handlers = rout.trigger
}

Grid.fill = Grid.define{
    name = 'fill',
    default_props = {},
    init = function(format, size, state, data)

        --TODO: check for correct format before overwriting value table
        state[2](fill(format, size, 1))
    end,
    handlers = rout.fill
}

Grid.number = Grid.define{
    name = 'number',
    default_props = {}
}

return Grid
