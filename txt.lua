_txt = _group:new()
_txt.devk = 'screen'

_txt.affordance = _screen:new {
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
    formatter = function(s, ...) return ... end,
    scroll_window = nil, -- 6
    scroll_focus = nil, -- 3 or { 1, 6 }
    selection = nil -- 1 or { 1, 2 } or { x = 1, y = 2 }, or { { x = 1, y = 2 }, x = 3, y = 4 } }
}

_txt.affordance.output.txt = function(s) return 'wrong' end

local rout = include 'lib/nest/routines/txt'

_txt.affordance.output.redraw = rout.redraw

_txt.label = _txt.affordance:new {
    value = 'label'
} 

_txt.label.output.txt = function(s) return s.p_.v end

_txt.labelaffordance = _txt.affordance:new {
    label = function(s) if s.p and type(s.p.k) == 'string' then return s.p.k end end,
    lvl = function(s) return s.p_.label and { 4, 15 } or 15 end,
    step = 0.01,
    margin = 5
}

local function labeltxt(s)
    if s.p_.label then 
        if type(s.p_.v) == 'table' then
            local vround = {}
            for i,v in ipairs(s.p_.v) do vround[i] = util.round(v, s.p_.step) end
            return { s.p_.label, s:formatter(table.unpack(vround)) }
        else return { s.p_.label, s:formatter(util.round(s.p_.v, s.p_.step)) } end
    else return s:formatter(util.round(s.p_.v, s.p_.step)) end
end

_txt.labelaffordance.output.txt = labeltxt

_txt.enc = _group:new()
_txt.enc.devk = 'enc'

_txt.enc.number = _enc.number:new()
_txt.labelaffordance:copy(_txt.enc.number)

_txt.enc.control = _enc.control:new()
_txt.enc.control.step = function(s) return s.p_.controlspec.step end
_txt.labelaffordance:copy(_txt.enc.control)

_txt.option = _txt.affordance:new()
_txt.option.lvl = { 4, 15 }
_txt.option.selected = function(s) return s.p_.v end
_txt.option.output.txt = function(s) return s.p_.options end
_txt.option.output.ltxt = function(s)
    if s.p_.label then 
        if type(s.p_.v) == 'table' then
            return { s.p_.label, s.p_.options[s.p_.v.y][s.p_.v.x] }
        else return { s.p_.label, s.p_.options[s.p_.v] } end
    else return s.p_.options[s.p_.v] end
end

_txt.enc.option = _enc.option:new()
_txt.option:copy(_txt.enc.option)

_txt.list = _txt.affordance:new { lvl = { 4, 15 }, flow = 'y' }
_txt.list.selected = function(s) return s.p_.v end
_txt.list.output.txt = function(s)
    local ret = {}
    for i,v in ipairs(s.items) do
        
        --meh, this should be in an initialization function but init stuff is being overwritten by the enc type ://
        v.enabled = function() return i == math.floor(s.p_.v) end

        ret[i] = v.output.ltxt and v.output:ltxt() or v.output:txt()
    end

    return ret
end
_txt.list.options = function(s) return s.items end

_txt.enc.list = _enc.option:new()
_txt.list:copy(_txt.enc.list)

_txt.key = _group:new()
_txt.key.devk = 'key'

_txt.key.number = _key.number:new()
_txt.labelaffordance:copy(_txt.key.number)

_txt.key.option = _key.option:new()
_txt.option:copy(_txt.key.option)

_txt.binary = _txt.affordance:new {
    lvl = { 4, 15 },
    label = function(s) return s.p and s.p.k end
}
_txt.binary.selected = function(s) 
    if type(s.p_.n) == 'table' then
        local ret = {}
        for i,v in ipairs(s.p_.v) do
            if v > 0 then ret[#ret + 1] = i end
        end
        
        return ret
    else return s.p_.v end
end
_txt.binary.output.txt = function(s) return s.p_.label end
_txt.binary.output.ltxt = labeltxt

_txt.key.trigger = _key.trigger:new { blinktime = 0.2 }
_txt.binary:copy(_txt.key.trigger)
--_txt.key.trigger.selected = 0
_txt.key.trigger.output.handler = function(s)
    clock.run(function()
        clock.sleep(s.blinktime)
        if type(s.p_.n) == 'table' then
            for i,v in ipairs(s.p_.v) do
                s.p_.v[i] = 0
            end
        else s.p_.v = 0 end

        s.devs[s.devk].dirty = true
    end)
end

_txt.key.momentary = _key.momentary:new()
_txt.binary:copy(_txt.key.momentary)

_txt.key.toggle = _key.toggle:new { lvl = _txt.binary.lvl }
_txt.binary:copy(_txt.key.toggle)

_txt.key.list = _key.option:new()
_txt.list:copy(_txt.key.list)
