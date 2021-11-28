local rout = include 'lib/nest/routines/arc'

_arc = _group:new()
_arc.devk = 'a'

_arc.key = _group:new()
_arc.key.devk = 'akey'

_arc.delta = _affordance:new { n = 1, input = _input:new() }

_arc.delta.input.filter = function(s, args)
    if args[1] == s.p_.n then return args end
end

_arc.delta.input.handler = rout.delta.input.point

_arc.fill = _affordance:new {
    v = 0,
    n = 1,
    x = { 33, 32 },
    lvl = 15,
    aa = false,
    output = _output:new()
}

_arc.fill.output.redraw = rout.fill.redraw.point

_arc.affordance = _arc.fill:new {
    v = 0,
    min = 0, max = 1,
    sens = 1,
    wrap = false,
    input = _input:new()
}

_arc.affordance.input.filter = function(s, args)
    if args[1] == s.p_.n then
        return { args[1], args[2] * s.p_.sens }
    end
end

_arc.number = _arc.affordance:new {
    cycle = 1.0,
    inc = 1/64,
    indicator = 1
}

_arc.number.input.handler = rout.number.input.point

_arc.number.output.redraw = rout.number.redraw.point

_arc.control = _arc.affordance:new {
    x = { 42, 24 },
    lvl = { 0, 4, 15 },
    controlspec = nil,
    min = 0, max = 1,
    step = 0, --0.01,
    units = '',
    quantum = 0.01,
    warp = 'lin',
    wrap = false
}

_arc.control.copy = function(self, o)
    local cs = o.controlspec

    o = _arc.affordance.copy(self, o)

    o.controlspec = cs or controlspec.new(o.p_.min, o.p_.max, o.p_.warp, o.p_.step, o.v, o.p_.units, o.p_.quantum, o.p_.wrap)

    return o
end

_arc.control.input.handler = rout.control.input.point

_arc.control.output.redraw = rout.control.redraw.point

_arc.option = _arc.affordance:new {
    v = 1, -- { 1, 3 }
    options = 4,
    size = nil, -- 10, { 10, 10 20, 10 }
    include = nil,
    glyph = nil,
    min = 1, max = function(s) return s.options end,
    margin = 0
}

_arc.option.input.handler = rout.option.input.point

_arc.option.output.redraw = rout.option.redraw.point

_arc.key.affordance = _affordance:new { 
    n = 2,
    edge = 1,
    tdown = 0,
    input = _input:new()
}

_arc.key.affordance.input.filter = _arc.delta.input.filter

_arc.key.momentary = _arc.key.affordance:new()
_arc.key.momentary.input.handler = rout.key.momentary.input.point

_arc.key.trigger = _arc.key.affordance:new()
_arc.key.trigger.input.handler = rout.key.trigger.input.point

_arc.key.toggle = _arc.key.affordance:new()
_arc.key.toggle.input.handler = rout.key.toggle.input.point

-------------------------------------BINDERS----------------------------------------------

local pt = { separator = 0, number = 1, option = 2, control = 3, file = 4, taper = 5, trigger = 6, group = 7, text = 8, binary = 9 }
local tp = tab.invert(pt)
local err = function(t) print(t .. '.param: cannot bind to param of type '..tp[p.t]) end
local gp = function(id) 
    local p = params:lookup_param(id)
    if p then return p
    else print('_affordance.param: no param with id "'..id..'"') end
end
local lnk = function(s, id, t, o)
    if type(s.v) == 'table' then
        print(t .. '.param: value cannot be a table')
    else
        o.label = o.label or s.label or gp(id).name or id
        o.value = function() return params:get(id) end
        o.action = function(s, v) params:set(id, v) end
        s:merge(o)
    end
end

_arc.control.param = function(s, id)
    local p,t = gp(id), '_arc.control'

    if p.t == pt.control then
        lnk(s, id, t, {
            controlspec = p.controlspec,
        })
    else err(t) end; return s
end
_arc.number.param = function(s, id)
    local p,t = gp(id), '_arc.control'

    if p.t == pt.control then
        lnk(s, id, t, {
            min = p.controlspec.min, max = p.controlspec.max,
            cycle = s.cycle or (p.controlspec.max - p.controlspec.min)
        })
    else err(t) end; return s
end
_arc.option.param = function(s, id)
    local p,t = gp(id), '_arc.option'

    if p.t == pt.option then
        lnk(s, id, t, {
            options = #p.options
        })
    elseif p.t == pt.number then
        lnk(s, id, t, {
            options = p.max,
            min = p.min, max = p.max
        })
    else err(t) end; return s
end
