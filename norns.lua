tab = require 'tabutil'

-------------------------------------------CONNECT------------------------

nest_.connect = function(self, objects, fps)
    local devs = {}

    local fps = fps or 30

    for k,v in pairs(objects) do
        if k == 'g' or k == 'a' then
            local kk = k
            local vv = v

            local rd = function()
                vv:all(0)
                self:draw(kk) 
                vv:refresh()
            end
            
            devs[kk] = _dev:new {
                object = vv,
                -- redraw = function() 
                --     rd()
                -- end,
                refresh = function()
                    vv:refresh()
                end,
                handler = function(...)
                    self:process(kk, {...}, {})
                end
            }

            if k == 'a' then
                devs.akey = _dev:new {
                    handler = function(...)
                        self:process('akey', {...}, {})
                    end
                }

                v.key = devs.akey.handler
                v.delta = devs.a.handler

                arc_redraw = rd --global
                devs[kk].redraw = function() arc_redraw() end
            else
                v.key = devs.g.handler

                grid_redraw = rd --global
                devs[kk].redraw = function() grid_redraw() end
            end

        elseif k == 'm' or k == 'h' then
            local kk = k
            local vv = v

            devs[kk] = _dev:new {
                object = vv,
                handler = function(data)
                    self:process(kk, data, {})
                end
            }

            v.event = devs[kk].handler
        elseif k == 'enc' or k == 'key' then
            local kk = k
            local vv = v

            devs[kk] = _dev:new {
                handler = function(...)
                    self:process(kk, {...}, {})
                end
            }

            _G[kk] = devs[kk].handler
        elseif k == 'screen' then
            local kk = k

            devs[kk] = _dev:new {
                object = screen,
                refresh = function()
                    screen.update()
                end,
                --[[
                redraw = function()
                    screen.clear()
                    self:draw('screen')
                    screen.update()
                end
                --]]
               redraw = function() redraw() end
            }

            --redraw = devs[kk].redraw
            redraw = function()
                screen.clear()
                self:draw('screen')
                screen.update()
            end
        else 
            print('nest_.connect: invalid device key. valid options are g, a, m, h, screen, enc, key')
        end
    end

    local function linkdevs(obj) 
        if type(obj) == 'table' and obj.is_nest then
            rawset(obj._, 'devs', devs)
            
            --might not be needed with _output.redraw args
            for k,v in pairs(objects) do 
                rawset(obj._, k, v)
            end
            
            for k,v in pairs(obj) do 
                linkdevs(v)
            end
        end
    end

    linkdevs(self)
    
    local oi = self.init
    self.init = function(s)
        oi(s)

        s.drawloop = clock.run(function() 
            while true do 
                clock.sleep(1/fps)
                
                for k,v in pairs(devs) do 
                    --if k == 'screen' and (not _menu.mode) then v.redraw() --norns menu secret system dependency
                    if v.redraw and v.dirty then 
                        v.dirty = false
                        v.redraw()
                    end
                end
            end   
        end)
    end
    
    return self
end

nest_.disconnect = function(self)
    if self.drawloop then clock.cancel(self.drawloop) end
end
-----------------------------------SCREEN------------------------------------------------

_screen_group = _group:new()
_screen_group.devk = 'screen'

_screen_group.affordance = _affordance:new {
    aa = 0,
    output = _output:new()
}
_screen = _screen_group.affordance

------------------------------------ENC---------------------------------------------------

local rout = include 'lib/nest/routines/grid'

_enc = _group:new()
_enc.devk = 'enc'

_enc.affordance = _affordance:new { 
    n = 2,
    sens = 1,
    input = _input:new()
}

_enc.affordance.input.filter = function(self, args) -- args = { n, d }
    local n, d = args[1], args[2] * self.p_.sens
    if type(n) == "table" then 
        if tab.contains(self.p_.n, args[1]) then return n, d end
    elseif args[1] == self.p_.n then return n, d
    else return nil
    end
end

_enc.muxaffordance = _enc.affordance:new()

_enc.muxaffordance.input.filter = function(self, args) -- args = { n, d }
    local sens = self.p_.sens or 1
    local n, d = args[1], args[2] * sens
    if type(self.p_.n) == "table" then 
        if tab.contains(self.p_.n, args[1]) then return { "line", n, d } end
    elseif args[1] == self.p_.n then return { "point", n, d }
    else return nil
    end
end

_enc.muxaffordance.input.muxhandler = _obj_:new {
    point = function(s, z) end,
    line = function(s, v, z) end
}

_enc.muxaffordance.input.handler = function(s, k, ...)
    return s.muxhandler[k](s, ...)
end

local function minit(n)
    if type(n) == 'table' then
        local ret = {}
        for i = 1, #n do ret[i] = 0 end
        return ret
    else return 0 end
end

_enc.delta = _enc.muxaffordance:new()

_enc.delta.input.muxhandler = rout.enc.delta.input

_enc.number = _enc.muxaffordance:new {
    min = 1, max = 1,
    inc = 0.01,
    wrap = false
}

_enc.number.copy = function(self, o)
    o = _enc.muxaffordance.copy(self, o)

    local v = minit(o.p_.n)
    if type(o.v) ~= 'function' then
        if type(v) == 'table' and (type(o.v) ~= 'table' or (type(o.v) == 'table' and #o.v ~= #v)) then o.v = v end
    end

    return o
end

_enc.number.input.muxhandler = rout.enc.number.input

_enc.control = _enc.muxaffordance:new {
    controlspec = nil,
    min = 0, max = 1,
    step = 0.01,
    units = '',
    quantum = 0.01,
    warp = 'lin',
    wrap = false
}

_enc.control.copy = function(self, o)
    local cs = o.controlspec

    o = _enc.muxaffordance.copy(self, o)

    if not o.p_.controlspec then
        o.controlspec = controlspec.new(o.p_.min, o.p_.max, o.p_.warp, o.p_.step, o.v, o.p_.units, o.p_.quantum, o.p_.wrap)
    end

    local v = minit(o.p_.n)
    if type(o.v) ~= 'function' then
        if type(v) == 'table' and (type(o.v) ~= 'table' or (type(o.v) == 'table' and #o.v ~= #v)) then o.v = v end
    end
    return o
end

_enc.control.input.muxhandler = rout.enc.control.input

local tab = require 'tabutil'

_enc.option = _enc.muxaffordance:new {
    value = 1,
    --options = {},
    wrap = false
}

_enc.option.copy = function(self, o) 
    o = _enc.muxaffordance.copy(self, o)

    if type(o.p_.n) == 'table' then
        if type(o.v) ~= 'function' then
            if type(o.v) ~= 'table' then
                o.v = { x = 1, y = 1 }
            end
        end
    end

    return o
end

_enc.option.input.muxhandler = rout.enc.option.input

-----------------------------------KEY------------------------------------------------------

local edge = { rising = 1, falling = 0, both = 2 }

_key = _group:new()
_key.devk = 'key'

_key.affordance = _affordance:new { 
    n = 2,
    edge = 'rising',
    input = _input:new()
}

_key.affordance.input.filter = _enc.affordance.input.filter

_key.muxaffordance = _key.affordance:new()

_key.muxaffordance.input.filter = _enc.muxaffordance.input.filter

_key.muxaffordance.input.muxhandler = _obj_:new {
    point = function(s, z) end,
    line = function(s, v, z) end
}

_key.muxaffordance.input.handler = _enc.muxaffordance.input.handler

_key.number = _key.muxaffordance:new {
    inc = 1,
    wrap = false,
    min = 0, max = 10,
    edge = 'rising',
    tdown = 0
}

_key.number.input.muxhandler = rout.key.number.input

_key.option = _enc.muxaffordance:new {
    value = 1,
    --options = {},
    wrap = false,
    inc = 1,
    edge = 'rising',
    tdown = 0
}

_key.option.copy = function(self, o) 
    o = _enc.muxaffordance.copy(self, o)

    return o
end

_key.option.input.muxhandler = rout.key.option.input

_key.binary = _key.muxaffordance:new {
    fingers = nil
}

_key.binary.copy = function(self, o) 
    o = _key.muxaffordance.copy(self, o)

    rawset(o, 'list', {})

    local axis = o.p_.n
    local v = minit(axis)
    o.held = minit(axis)
    o.tdown = minit(axis)
    o.tlast = minit(axis)
    o.theld = minit(axis)
    o.vinit = minit(axis)
    o.blank = {}

    o.arg_defaults =  {
        minit(axis),
        minit(axis),
        nil,
        nil,
        o.list
    }

    if type(o.v) ~= 'function' then
        if type(v) == 'table' and (type(o.v) ~= 'table' or (type(o.v) == 'table' and #o.v ~= #v)) then o.v = v end
    end
    
    return o
end

_key.binary.input.muxhandler = rout.key.binary.input

_key.momentary = _key.binary:new()

_key.momentary.input.muxhandler = rout.key.momentary.input

_key.toggle = _key.binary:new { edge = 'rising', lvl = { 0, 15 } } -- it is wierd that lvl is being used w/o an output :/

_key.toggle.copy = function(self, o) 
    o = _key.binary.copy(self, o)

    rawset(o, 'toglist', {})

    local axis = o.p_.n

    --o.tog = minit(axis)
    o.ttog = minit(axis)

    o.arg_defaults = {
        minit(axis),
        minit(axis),
        nil,
        nil,
        o.toglist
    }

    return o
end

_key.toggle.input.muxhandler = rout.key.toggle.input

_key.trigger = _key.binary:new { edge = 'rising', blinktime = 0.1, persistent = false }

_key.trigger.copy = function(self, o) 
    o = _key.binary.copy(self, o)

    rawset(o, 'triglist', {})

    local axis = o.p_.n
    o.tdelta = minit(axis)

    o.arg_defaults = {
        minit(axis),
        minit(axis),
        nil,
        nil,
        o.triglist
    }
    
    return o
end

_key.trigger.input.muxhandler = rout.key.trigger.input

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
        --o.label = (s.label ~= nil) and s.label or gp(id).name or id
        o.value = function() return params:get(id) end
        o.action = function(s, v) params:set(id, v) end
        o.formatter = o.formatter or gp(id).formatter and 
            function(s,v) return gp(id).formatter({value = v}) end
        s:merge(o)
    end
end

_enc.control.param = function(s, id)
    local p,t = gp(id), '_enc.control'

    if p.t == pt.control then
        lnk(s, id, t, {
            controlspec = p.controlspec,
        })
    else err(t) end; return s
end
_enc.number.param = function(s, id)
    local p,t = gp(id), '_enc.number'

    if p.t == pt.number then
        lnk(s, id, t, {
            min = p.min, max = p.max, wrap = p.wrap, inc = 1
        })
    elseif p.t == pt.control then
        lnk(s, id, t, {
            min = p.controlspec.min, max = p.controlspec.max, wrap = p.controlspec.wrap,
        })
    else err(t) end; return s
end
_enc.option.param = function(s, id)
    local p,t = gp(id), '_enc.option'

    if p.t == pt.option then
        lnk(s, id, t, {
            options = p.options,  
        })
    else err(t) end; return s
end
_key.number.param = function(s, id)
    local p,t = gp(id), '_key.number'

    if p.t == pt.number then
        lnk(s, id, t, {
            min = p.min, max = p.max, wrap = p.wrap,
        })
    else err(t) end; return s
end
_key.option.param = function(s, id)
    local p,t = gp(id), '_key.option'

    if p.t == pt.option then
        lnk(s, id, t, {
            options = p.options,  
        })
    else err(t) end; return s
end
_key.toggle.param = function(s, id)
    local p,t = gp(id), '_key.toggle'

    if p.t == pt.binary then
        lnk(s, id, t, {})
    elseif p.t == pt.option then
        if type(s.v) == 'table' then
            print(t .. '.param: value cannot be a table')
        else
            s.value = function() return params:get(id) - 1 end
            s.action = function(s, v) params:set(id, v + 1) end
        end
    else err(t) end; return s
end
_key.momentary.param = function(s, id)
    local p = gp(id)

    if p.t == pt.binary then
        lnk(s, id, '_key.momentary', {})
    else err(t) end; return s
end
_key.trigger.param = function(s, id)
    local p,t = gp(id), '_key.trigger'

    if p.t == pt.binary then
        if type(s.v) == 'table' then
            print(t .. '.param: value cannot be a table')
        else
            --o.label = (s.label ~= nil) and s.label or gp(id).name or id
            s.action = function(s, v) params:delta(id) end
        end
    else err(t) end; return s
end

