tab = require 'tabutil'

---------------------------------------CONNET-----------------------------------------

nest_.connect = function(self, objects, fps)
    local devs = {}

    local fps = fps or 30

    for k,v in pairs(objects) do
        if k == 'g' or k == 'a' then
            local kk = k
            local vv = v
            
            devs[kk] = _dev:new {
                object = vv,
                redraw = function() 
                    vv:all(0)
                    self:draw(kk) 
                    vv:refresh()
                end,
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
            else
                v.key = devs.g.handler
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

-------------------------------------SCREEN--------------------------------------------------

_screen = _group:new()
_screen.devk = 'screen'

_screen.affordance = _affordance:new {
    aa = 0,
    output = _output:new()
}

--------------------------------------ENC--------------------------------------------------

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

_enc.delta.input.muxhandler = _obj_:new {
    point = function(s, n, d) 
        return d
    end,
    line = function(s, n, d) 
        local i = tab.key(s.p_.n, n)
        return d, i
    end
}

local function delta_number(self, value, d)
    local range = { self.p_.min, self.p_.max }

    local v = value + (d * self.inc)

    if self.p_.wrap then
        while v > range[2] do
            v = v - (range[2] - range[1]) - 1
        end
        while v < range[1] do
            v = v + (range[2] - range[1]) + 1
        end
    end

    local c = util.clamp(v, range[1], range[2])
    if value ~= c then
        return c
    end
end

_enc.number = _enc.muxaffordance:new {
    min = 1, max = 1,
    inc = 0.01,
    wrap = false
}

_enc.number.copy = function(self, o)
    o = _enc.muxaffordance.copy(self, o)

    local v = minit(o.p_.n)
    if type(v) == 'table' and (type(o.v) ~= 'table' or (type(o.v) == 'table' and #o.v ~= #v)) then o.v = v end

    return o
end

_enc.number.input.muxhandler = _obj_:new {
    point = function(s, n, d) 
        return delta_number(s, s.p_.v, d), d
    end,
    line = function(s, n, d) 
        local i = tab.key(s.p_.n, n)
        local v = delta_number(s, s.p_.v[i], d)
        if v then
            local del = minit(s.p_.n)
            del[i] = d
            s.p_.v[i] = v
            return s.p_.v, del
        end
    end
}

local function delta_control(self, v, d)
    local value = self.controlspec:unmap(v) + (d * self.controlspec.quantum)

    if self.controlspec.wrap then
        while value > 1 do
            value = value - 1
        end
        while value < 0 do
            value = value + 1
        end
    end
    
    local c = self.controlspec:map(util.clamp(value, 0, 1))
    if v ~= c then
        return c
    end
end

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

    o.controlspec = cs or controlspec.new(o.p_.min, o.p_.max, o.p_.warp, o.p_.step, o.v, o.p_.units, o.p_.quantum, o.p_.wrap)

    local v = minit(o.p_.n)
    if type(v) == 'table' and (type(o.v) ~= 'table' or (type(o.v) == 'table' and #o.v ~= #v)) then o.v = v end

    return o
end

_enc.control.input.muxhandler = _obj_:new {
    point = function(s, n, d) 
        local last = s.p_.v
        return delta_control(s, s.p_.v, d), s.p_.v - last 
    end,
    line = function(s, n, d) 
        local i = tab.key(s.p_.n, n)
        local v = delta_control(s, s.p_.v[i], d)
        if v then
            local last = s.p_.v[i]
            local del = minit(s.p_.n)
            s.p_.v[i] = v
            del[i] = v - last
            return s.p_.v, del
        end
    end
}

local tab = require 'tabutil'

local function delta_option_point(self, value, d, wrap_scoot)
    local i = value or 0
    local v = i + d
    local size = #self.p_.options + 1 - self.p_.sens

    if self.wrap then
        while v > size do
            v = v - size + (wrap_scoot and 1 or 0)
        end
        while v < 1 do
            v = v + size + 1
        end
    end

    local c = util.clamp(v, 1, size)
    if i ~= c then
        return c
    end
end

local function delta_option_line(self, value, dx, dy, wrap_scoot)
    local i = value.x
    local j = value.y
    local sizey = #self.p_.options + 1 - self.p_.sens

    vx = i + (dx or 0)
    vy = j + (dy or 0)

    if self.wrap then
        while vy > sizey do
            vy = vy - sizey + (wrap_scoot and 1 or 0)
        end
        while vy < 1 do
            vy = vy + sizey + 1
        end
    end

    local cy = util.clamp(vy, 1, sizey)
    local sizex = #self.p_.options[cy] + 1 - self.p_.sens

    if self.wrap then
        while vx > sizex do
            vx = vx - sizex
        end
        while vx < 1 do
            vx = vx + sizex + 1
        end
    end

    local cx = util.clamp(vx, 1, sizex)

    if i ~= cx or j ~= cy then
        value.x = cx
        value.y = cy
        return value
    end
end

_enc.option = _enc.muxaffordance:new {
    value = 1,
    --options = {},
    wrap = false
}

_enc.option.copy = function(self, o) 
    o = _enc.muxaffordance.copy(self, o)

    if type(o.p_.n) == 'table' then
        if type(o.v) ~= 'table' then
            o.v = { x = 1, y = 1 }
        end
    end

    return o
end

_enc.option.input.muxhandler = _obj_:new {
    point = function(s, n, d) 
        local v = delta_option_point(s, s.p_.v, d, true)
        return v, s.p_.options[v], d
    end,
    line = function(s, n, d) 
        local i = tab.key(s.p_.n, n)
        local dd = { 0, 0 }
        dd[i] = d
        local v = delta_option_line(s, s.p_.v, dd[2], dd[1], true)
        if v then
            local del = minit(s.p_.n)
            del[i] = d
            return v, s.p_.options[v.y][v.x], del
        end
    end
}

-------------------------------------LINK----------------------------------------------

local pt = { separator = 0, number = 1, option = 2, control = 3, file = 4, taper = 5, trigger = 6, group = 7, text = 8, binary = 9 }
local tp = tab.invert(pt)
local err = function(t) print(t .. '.link: cannot link to param of type '..tp[p.t]) end
local gp = function(id) return params:lookup_param(id) end
local lnk = function(s, id, t, o)
    if type(s.v) == 'table' then
        print(t .. '.link: value cannot be a table')
    else
        o.label = p.name or id
        o.value = function() return params:get(id) end
        o.action = function(s, v) params:set(id, v) end
        s:merge(o, true)
    end
end

_enc.control.link = function(s, id)
    local p,t = gp(id), '_enc.control'

    if p.t == pt.control then
        lnk(s, id, t, {
            controlspec = p.controlspec,
        })
    else err(t) end; return s
end
_enc.number.link = function(s, id)
    local p,t = gp(id), '_enc.number'

    if p.t == pt.number then
        lnk(s, id, t, {
            min = p.min, max = p.max, wrap = p.wrap,
        })
    else err(t) end; return s
end
_enc.option.link = function(s, id)
    local p,t = gp(id), '_enc.option'

    if p.t == pt.option then
        lnk(s, id, t, {
            options = p.options,  
        })
    else err(t) end; return s
end
_key.number.link = function(s, id)
    local p,t = gp(id), '_key.number'

    if p.t == pt.number then
        lnk(s, id, t, {
            min = p.min, max = p.max, wrap = p.wrap,
        })
    else err(t) end; return s
end
_key.option.link = function(s, id)
    local p,t = gp(id), '_key.option'

    if p.t == pt.option then
        lnk(s, id, t, {
            options = p.options,  
        })
    else err(t) end; return s
end
local bin = function(t) return function(s, id)
    local p = gp(id)

    if p.t == pt.binary then
        lnk(s, id, t, {})
    else err(t) end; return s
end end
_key.trigger.link = bin('_key.trigger')
_key.toggle.link = bin('_key.toggle')
_key.momentary.link = bin('_key.momentary')
