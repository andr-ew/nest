local rout = include 'lib/nest/routines/norns'

local Key, Enc = {}, {}

nest.connect_enc = function(loop)
    local input_flags = nest.define_connection{
        device_name = 'enc'
    }

    enc = function(n, d)
        input_flags(n, d)
        loop()
    end
end

-- nest.handle_input.enc = function(...)
--     nest.handle_input.device('enc', ...)
-- end

nest.connect_key = function(loop)
    local input_flags = nest.define_connection{
        device_name = 'key'
    }

    key = function(n, z)
        input_flags(n, z)
        loop()
    end
end

-- nest.handle_input.key = function(...)
--     nest.handle_input.device('key', ...)
-- end

--contained, fmt, size, hargs

local filter = function(self, args) -- args = { n, d }
    local sens = self.p_.sens or 1
    local n, d = args[1], args[2] * sens

    if type(self.p_.n) == "table" then 
        local contained = tab.contains(self.p_.n, args[1])
        return contained, "line", #self.p_.n, { n, d }
    else
        local contained = args[1] == self.p_.n
        return contained, "point", nil, { n, d }
    end
end

Enc.define = nest.define_group_def{
    name = 'Enc',
    device_input = 'enc',
    device_redraw = nil,
    default_props = {
        n = 2,
        sens = 1,
    },
    filter = filter
}

Key.define = nest.define_group_def{
    name = 'Key',
    device_input = 'key',
    device_redraw = nil,
    default_props = {
        n = 2,
        edge = 'rising',
    },
    filter = filter
}

Enc.delta = Enc.define{
    name = 'delta',
    default_props = {},
    init = function() end,
    handlers = rout.enc.delta.input
}

local function fill(format, size, n)
    if format=='line' then
        local ret = {}
        for i = 1, size do ret[i] = n end
        return ret
    else return n end
end
local function fill_option(format, size, n)
    if format=='line' then
        return { x = n, y = n }
    else return n end
end

Enc.number = Enc.define{
    name = 'number',
    default_props = {
        min = 0, max = 1,
        inc = 0.01,
        wrap = false
    },
    init = function(format, size, state, data, props) 
        --TODO: check for correct format before overwriting value
        state[2](fill(format, size, props.min))
    end,
    handlers = rout.enc.number
}

local cs = require 'controlspec'

Enc.control = Enc.define{
    name = 'control',
    default_props = {
        controlspec = cs.new()
    },
    init = function(format, size, state, data, props) 
        local dv = props.controlspec.default or props.controlspec.minval

        --TODO: check for correct format before overwriting value
        state[2](fill(format, size, dv))
    end,
    handlers = rout.enc.control
}

Enc.option = Enc.define{
    name = 'option',
    default_props = {
        wrap = false
    },
    init = function(format, size, state, data) 
        --TODO: check for correct format before overwriting value
        state[2](fill_option(format, size, 1))
    end,
    handlers = rout.enc.option
}

Key.number = Key.define{
    name = 'number',
    default_props = {
        inc = 1,
        wrap = false,
        min = 0, max = 10,
        edge = 'rising',
    },
    init = function(format, size, state, data, props) 
        --TODO: check for state before overwrite
        state[2](0)

        data.tdown = 0
    end,
    handlers = rout.key.number
}

Key.option = Key.define{
    name = 'option',
    default_props = {
        wrap = false,
        inc = 1,
        edge = 'rising',
    },
    init = function(format, size, state, data, props)
        --TODO: check for state before overwrite
        state[2](1)

        data.tdown = 0
    end,
    handlers = rout.key.option
}

local init_binary = function(format, size, state, o)

    --TODO: check for correct format before overwriting value
    state[2](fill(format, size, 0))
    
    --TODO: impliment level clocks
    -- o.list = {}
    -- o.held = fill(format, size, 0)
    -- o.tdown = fill(format, size, 0)
    -- o.tlast = fill(format, size, 0)
    -- o.theld = fill(format, size, 0)
    -- o.vinit = fill(format, size, 0)
    -- o.lvl_frame = fill(format, size, 0)
    -- o.lvl_clock = fill(format, size, 0)
    -- o.blank = {}


    o.list = {}
    o.held = fill(format, size, 0)
    o.tdown = fill(format, size, 0)
    o.tlast = fill(format, size, 0)
    o.theld = fill(format, size, 0)
    o.vinit = fill(format, size, 0)
    o.blank = {}
end

Key.momentary = Key.define{
    name = 'momentary',
    default_props = {},
    init = function(format, size, state, data, props)
        init_binary(format, size, state, data)
    end,
    handlers = rout.key.momentary
}

Key.toggle = Key.define{
    name = 'toggle',
    default_props = { edge = 'rising', lvl = { 0, 15 } },
    init = function(format, size, state, data, props)
        init_binary(format, size, state, data)

        data.toglist = {}
        data.ttog = fill(format, size, 0)
    end,
    handlers = rout.key.toggle
}

Key.trigger = Key.define{
    name = 'trigger',
    default_props = { edge = 'rising', blinktime = 0.1, },
    init = function(format, size, state, data, props)
        init_binary(format, size, state, data)

        data.triglist = {}
        data.tdela = fill(format, size, 0)
    end,
    handlers = rout.key.trigger
}

return Key, Enc
