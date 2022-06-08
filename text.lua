local rout = include 'lib/nest/routines/txt'

local Text = {}

local defs = nest.defs

local handlers = {
    redraw = {
        point = rout.redraw,
        line = rout.redraw,
    }
}

Text.define = nest.define_group_def{
    name = 'Text',
    device_redraw = 'screen',
    default_props = {
        n = 2,
        edge = rising,
        aa = 0,
        font_face = 1,
        font_size = 8,
        lvl = 15,
        border = 0,
        fill = 0,
        padding = 0,
        margin = 5,
        x = 1,
        y = 1,
        size = nil,
        flow = 'x',
        align = 'left',
        line_wrap = nil,
        font_headroom = 3/8,
        font_leftroom = 1/16,
        formatter = function(...) return ... end,
        scroll_window = nil, -- 6
        scroll_focus = nil, -- 3 or { 1, 6 }
        selection = nil -- 1 or { 1, 2 } or { x = 1, y = 2 }, or { { x = 1, y = 2 }, x = 3, y = 4 } }
    },
    handlers = handlers
}

Text.label = Text.define{
    name = 'label',
    default_props = {},
    init = function(format, size, state, data, props) 
        data.txt = function(s) 
            return s.p_.label
        end
    end,
    filter = function()
        --contained, fmt, size, hargs
        return nil, 'point'
    end
}

local lab_comp = {
    props = {
        --FIXME (?)
        --lvl = function(s, props) return props.label and { 4, 15 } or 15 end,
        lvl = { 4, 16 },
        step = 0.01,
        margin = 5
    },
    init = function(format, size, state, data, props) 
        --data.formatter = props.formatter or function(s, ...) return ... end
        data.txt = function(s) 
            local step = s.p_.controlspec and s.p_.controlspec.step or s.p_.step
            if step < (s.p_.step or 0) then step = s.p_.step end
            
            if s.p_.label then 
                if type(s.p_.v) == 'table' then
                    local vround = {}
                    for i,v in ipairs(s.p_.v) do vround[i] = util.round(v, step) end
                    return { s.p_.label, props.formatter(table.unpack(vround)) }
                else return { s.p_.label, props.formatter(util.round(s.p_.v, step)) } end
            else return props.formatter(util.round(s.p_.v, step)) end
        end
    end,
    handlers = handlers
}

local join = function(...)
    local tabs = { ... }
    local ret = {}

    for _,tab in ipairs(tabs) do
        for k,v in pairs(tab) do
            ret[k] = v
        end
    end

    return ret
end

Text.enc = {}

Text.enc.number = Text.define{
    name = 'enc.number', 
    device_input = 'enc',
    default_props = join(
        lab_comp.props, 
        defs.Enc.number.default_props
    ),
    init = function(...) 
        defs.Enc.number.init(...)
        lab_comp.init(...)
    end,
    handlers = {
        input = defs.Enc.number.handlers.input,
        change = defs.Enc.number.handlers.change,
        redraw = lab_comp.handlers.redraw,
    },
    filter = defs.Enc.number.filter
}

Text.enc.control = Text.define{
    name = 'enc.control', 
    device_input = 'enc',
    default_props = join(
        lab_comp.props, 
        defs.Enc.control.default_props
    ),
    init = function(...) 
        defs.Enc.control.init(...)
        lab_comp.init(...)
    end,
    handlers = {
        input = defs.Enc.control.handlers.input,
        change = defs.Enc.control.handlers.change,
        redraw = lab_comp.handlers.redraw,
    },
    filter = defs.Enc.control.filter
}

local opt_comp = {
    props = {
        lvl = { 4, 15 },
        selected = function(v) return v end,
    },
    init = function(format, size, state, data, props) 
        data.txt = function(s) return s.p_.options end
    end,
    handlers = handlers
}

Text.enc.option = Text.define{
    name = 'enc.option',
    device_input = 'enc',
    default_props = join(
        opt_comp.props, 
        defs.Enc.option.default_props
    ),
    init = function(...) 
        defs.Enc.option.init(...)
        opt_comp.init(...)
    end,
    handlers = {
        input = defs.Enc.option.handlers.input,
        change = defs.Enc.option.handlers.change,
        redraw = opt_comp.handlers.redraw,
    },
    filter = defs.Enc.option.filter
}

--TODO: Text.enc.list ?

Text.key = {}

Text.key.number = Text.define{
    name = 'key.number', 
    device_input = 'key',
    default_props = join(
        lab_comp.props, 
        defs.Key.number.default_props
    ),
    init = function(...) 
        defs.Key.number.init(...)
        lab_comp.init(...)
    end,
    handlers = {
        input = defs.Key.number.handlers.input,
        change = defs.Key.number.handlers.change,
        redraw = lab_comp.handlers.redraw,
    },
    filter = defs.Key.number.filter
}

Text.key.option = Text.define{
    name = 'key.option', 
    device_input = 'key',
    default_props = join(
        opt_comp.props, 
        defs.Key.option.default_props
    ),
    init = function(...) 
        defs.Key.option.init(...)
        opt_comp.init(...)
    end,
    handlers = {
        input = defs.Key.option.handlers.input,
        change = defs.Key.option.handlers.change,
        redraw = opt_comp.handlers.redraw,
    },
    filter = defs.Key.option.filter
}

local bin_comp = {
    props = {
        lvl = { 4, 15 },
        selected = function(v) 
            if type(v) == 'table' then
                local ret = {}
                for i,vv in ipairs(v) do
                    if vv > 0 then ret[#ret + 1] = i end
                end
                return ret
            else return v or 0 end
        end
    },
    init = function(format, size, state, data, props) 
        data.txt = function(s) return s.p_.label or '.' end
    end,
    handlers = handlers
}

Text.key.momentary = Text.define{
    name = 'key.momentary', 
    device_input = 'key',
    default_props = join(
        bin_comp.props, 
        defs.Key.momentary.default_props
    ),
    init = function(...) 
        defs.Key.momentary.init(...)
        bin_comp.init(...)
    end,
    handlers = {
        input = defs.Key.momentary.handlers.input,
        change = defs.Key.momentary.handlers.change,
        redraw = bin_comp.handlers.redraw,
    },
    filter = defs.Key.momentary.filter
}

Text.key.toggle = Text.define{
    name = 'key.toggle', 
    device_input = 'key',
    default_props = join(
        defs.Key.toggle.default_props,
        bin_comp.props
    ),
    init = function(...) 
        defs.Key.toggle.init(...)
        bin_comp.init(...)
    end,
    handlers = {
        input = defs.Key.toggle.handlers.input,
        change = defs.Key.toggle.handlers.change,
        redraw = bin_comp.handlers.redraw,
    },
    filter = defs.Key.toggle.filter
}

local trig_change = function(s)
    clock.run(function()
        clock.sleep(s.p_.blinktime)
        if type(s.p_.n) == 'table' then
            for i,v in ipairs(s.p_.v) do
                s.p_.v[i] = 0
            end
        else s.state[2](0) end

        s.devs.screen.dirty = true
    end)
end

Text.key.trigger = Text.define{
    name = 'key.trigger', 
    device_input = 'key',
    default_props = join(
        defs.Key.trigger.default_props,
        bin_comp.props
    ),
    init = function(...) 
        defs.Key.trigger.init(...)
        bin_comp.init(...)
    end,
    handlers = {
        input = defs.Key.trigger.handlers.input,
        redraw = bin_comp.handlers.redraw,
        change = { point = trig_change, line = trig_change }
    },
    filter = defs.Key.trigger.filter
}

return Text
