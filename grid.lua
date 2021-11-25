local rout = include 'lib/nest/routines/grid'

local Grid = {}

nest.connect_grid = function(loop, g, fps)
    local 
        input_flags, 
        redraw_flags, 
        begin_loop 
    = nest.define_connection{
        device_name = 'grid',
        device = g,
        fps = fps
    }

    g.key = function(x, y, z)
        input_flags(x, y, z)
        loop()
    end

    local redraw_grid = function()
        g:all(0)

        redraw_flags()
        loop()

        g:refresh()
    end

    begin_loop(redraw_grid)

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

Grid.define = nest.define_group_def{
    name = 'Grid',
    device_input = 'grid',
    device_redraw = 'grid',
    default_props = {
        x = 1, y = 1, lvl = 15,
    },
    filter = filter
}

local function fill(format, size, n) 
    local ret = {}

    if format=='plane' then
        for x = 1,size.x do
            ret[x] = {}
            for y = 1,size.y do
                ret[x][y] = n
            end
        end
    elseif format=='line_x' or format=='line_y' then
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

local input_contained_wrap = function(s, inargs, axis_size)
    inargs = inargs or { -1, -1 }
    local w, x, y = s.p_.wrap, inargs[1], inargs[2]
    if axis_size.x then
        for i = 1, axis_size.x do
            local maj = (i-1)%w + 1
            local min = (i-1)//w + 1

            if maj + s.p_.x[1] - 1 == x and min + s.p_.y - 1 == y then return true, i end
        end
    else
        --TODO: modified logic for vertical affordance
    end
end

local filter_wrap = function(s, args)
    local contained, axis_size = input_contained(s, args)

    if (s.p_.wrap~=nil) and ((axis_size.x == nil) ~= (axis_size.y == nil)) then
        local cont, i = input_contained_wrap(s, args, axis_size)
        
        return contained, "line", args, (axis_size.x or axis_size.y) and { i, nil, args[3] }
    end

    if axis_size.x == nil and axis_size.y == nil then
        return  contained, "point", nil, args and { nil, nil, args[3] }
    elseif axis_size.x ~= nil and axis_size.y ~= nil then
        return contained, "plane", axis_size, args and { args[1] - s.p_.x[1] + 1, s.p_.y[2] - args[2] + 1, args[3] }
    else
        if axis_size.x ~= nil then
            return contained, "line_x", axis_size.x, args and { args[1] - s.p_.x[1] + 1, nil, args[3] }
        elseif axis_size.y ~= nil then
            return contained, "line_y", axis_size.y, args and { s.p_.y[2] - args[2] + 1, nil, args[3] }
        end
    end
end

Grid.number = Grid.define{
    name = 'number',
    default_props = {
        edge = 'rising', fingers = nil, tdown = 0, filtersame = true, count = { 1, 1 }, min = 1, max = math.huge
    },
    init = function(format, size, state, data)
        local def = format == 'plane' and { x=1, y=1 } or 1
        state[2](state[1] or def)

        data.vlast = state[1] or def
        data.hlist = {}
    end,
    handlers = rout.number,
    filter = filter_wrap,
}

local cs = require 'controlspec'

Grid.control = Grid.define{
    name = 'control',
    default_props = {
        edge = 'rising', fingers = nil, tdown = 0, filtersame = true, count = { 1, 1 }, min = 1, max = math.huge,
        lvl = { 0, 4, 15 },
        controlspec = cs.new(),
        filtersame = false,
    },
    init = function(format, size, state, data, props)
        local dv = props.controlspec.default or props.controlspec.minval
        local def = format == 'plane' and { x=dv, y=dv } or dv
        state[2](state[1] or def)

        data.vlast = state[1] or def
        data.hlist = {}
    end,
    handlers = rout.control
}

Grid.range = Grid.define{
    name = 'range',
    default_props = {
        edge = 'rising'
    },
    init = function(format, size, state, data, props)
        state[2](
            format == 'plane'
            and { { x = 0, y = 0 }, { x = 0, y = 0 } }
            or { 0, 0 }
        )
        
        data.hlist = {}
        data.tdown = 0
    end,
    handlers = rout.range
}

--TODO: Grid.pattern

return Grid
