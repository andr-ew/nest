local rout = include 'lib/nest/routines/arc'

local Arc = {}

nest.connect_arc = function(render, a, fps)
    local 
        input_flags, 
        redraw_flags, 
        begin_render 
    = nest.define_connection{
        device_name = 'arc',
        device = a,
        fps = fps or 120
    }

    a.delta = function(n, d)
        input_flags(n, d)
        render()
    end

    --TODO: a.key

    local redraw_arc = function()
        a:all(0)

        redraw_flags()
        render()

        a:refresh()
    end

    begin_render(redraw_arc)

    do
        local input_flags = nest.define_connection{
            device_name = 'arc_key'
        }

        a.key = function(n, z)
            input_flags(n, z)
            render()
        end
    end

    return redraw_arc
end

--contained, fmt, size, hargs
local filter = function(s, args)
    args = args or { 0, 0 }
    return args[1] == s.p_.n, 'point', nil, { args[1], args[2] * s.p_.sens }
end

Arc.define = nest.define_group_def{
    name = 'Arc',
    device_input = 'arc',
    device_redraw = 'arc',
    default_props = {
        n = 1,
        x = { 33, 32 },
        lvl = 15,
        aa = false,
        min = 0, max = 1,
        sens = 1/2,
        wrap = false,
    },
    filter = filter,
    init = function(format, size, state, data, props) 
        --TODO: check for state before overwrite
        state[2](0)
    end,
}

Arc.delta = Arc.define{
    name = 'delta',
    device_redraw = false,
    default_props = {},
    handlers = rout.delta,
}

Arc.fill = Arc.define{
    name = 'fill',
    device_input = false,
    default_props = {},
    handlers = rout.fill,
}

Arc.number = Arc.define{
    name = 'number',
    default_props = {
        cycle = 1.0,
        inc = 1/64,
        indicator = 1
    },
    handlers = rout.number,
}

local cs = require 'controlspec'

Arc.control = Arc.define{
    name = 'control',
    default_props = {
        x = { 42, 24 },
        lvl = { 0, 4, 15 },
        controlspec = cs.new(),
    },
    handlers = rout.control,
}

Arc.option = Arc.define{
    name = 'option',
    default_props = {
        options = 4,
        size = nil, -- 10, { 10, 10 20, 10 }
        include = nil,
        glyph = nil,
        min = 1, 
        max = function(v, props) return props.options end,
        margin = 0
    },
    handlers = rout.option,
    init = function(format, size, state, data, props) 
        --TODO: check for state before overwrite
        state[2](1)
    end,
}

Arc.key = {}

Arc.key.define = nest.define_group_def{
    name = 'Arc.key',
    device_input = 'arc_key',
    device_redraw = nil,
    default_props = {
        n = 2,
        edge = 1,
        sens = 1,
    },
    filter = filter,
    init = function(format, size, state, data, props) 
        --TODO: check for state before overwrite
        state[2](0)
        data.tdown = 0
    end,
}

Arc.key.momentary = Arc.key.define{
    name = 'momentary',
    default_props = {},
    handlers = rout.key.momentary,
}
Arc.key.trigger = Arc.key.define{
    name = 'trigger',
    default_props = {},
    handlers = rout.key.trigger,
}
Arc.key.toggle = Arc.key.define{
    name = 'toggle',
    default_props = {},
    handlers = rout.key.toggle,
}

return Arc
