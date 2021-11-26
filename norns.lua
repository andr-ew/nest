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

return Key, Enc
