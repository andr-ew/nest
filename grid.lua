local tab = require 'tabutil'

local rout = include 'lib/nest/routines/grid'

_grid = _group:new()
_grid.devk = 'g'

_grid.affordance = _affordance:new {
    v = 0,
    x = 1,
    y = 1,
    lvl = 15,
    input = _input:new(),
    output = _output:new()
}

local input_contained = function(s, inargs)
    local contained = { x = false, y = false }
    local axis_size = { x = nil, y = nil }

    local args = { x = inargs[1], y = inargs[2] }

    for i,v in ipairs{"x", "y"} do
        if type(s.p_[v]) == "table" then
            if #s.p_[v] == 1 then
                s[v] = s.p_[v][1]
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

_grid.affordance.input.filter = function(s, args)
    if input_contained(s, args) then
        return args
    else return nil end
end

_grid.muxaffordance = _grid.affordance:new()

-- update -> filter -> handler -> muxhandler -> action -> v

_grid.muxaffordance.input.muxhandler = _obj_:new {
    point = { function(s, z) end },
    line = { function(s, v, z) end },
    plane = { function(s, x, y, z) end }
}

_grid.muxaffordance.input.handler = function(s, k, ...)
    return s.muxhandler[k](s, ...)
end

_grid.muxaffordance.input.filter = function(s, args)
    local contained, axis_size = input_contained(s, args)

    if contained then
        if axis_size.x == nil and axis_size.y == nil then
            return { "point", nil, nil, args[3] }
        elseif axis_size.x ~= nil and axis_size.y ~= nil then
            return { "plane", args[1] - s.p_.x[1] + 1, s.p_.y[2] - args[2] + 1, args[3] }
        else
            if axis_size.x ~= nil then
                return { "line", args[1] - s.p_.x[1] + 1, nil, args[3] }
            elseif axis_size.y ~= nil then
                return { "line", s.p_.y[2] - args[2] + 1, nil, args[3] }
            end
        end
    else return nil end
end

_grid.muxaffordance.output.muxredraw = _obj_:new {
    point = function(s) end,
    line_x = function(s) end,
    line_y = function(s) end,
    plane = function(s) end
}

local function redrawfilter(s)
    local has_axis = { x = false, y = false }

    for i,v in ipairs{"x", "y"} do
        if type(s.p_[v]) == "table" then
            if #s.p_[v] == 1 then
            elseif #s.p_[v] == 2 then
                has_axis[v] = true
            end
        end
    end
    
    if has_axis.x == false and has_axis.y == false then
        return 'point'
    elseif has_axis.x and has_axis.y then
        return 'plane'
    else
        if has_axis.x then
            return 'line_x'
        elseif has_axis.y then
            return 'line_y'
        end
    end
end

_grid.muxaffordance.output.redraw = function(s, v, g)
    return s.muxredraw[redrawfilter(s)](s, g, v)
end

_grid.binary = _grid.muxaffordance:new({ count = nil, fingers = nil }) -- local supertype for binary, toggle, trigger

local function minit(axis, n) 
    n = type(n) == 'number' and n or 0
    local v
    if axis.x and axis.y then 
        v = _obj_:new()
        for x = 1, axis.x do 
            v[x] = _obj_:new()
            for y = 1, axis.y do
                v[x][y] = n
            end
        end
    elseif axis.x or axis.y then
        v = _obj_:new()
        for x = 1, (axis.x or axis.y) do 
            v[x] = n
        end
    else 
        v = n
    end

    return v
end

local binaryvals = function(o)
    o.list = _obj_:new()

    local _, axis = input_contained(o, { -1, -1 })

    local v = minit(axis, o.v)
    o.held = minit(axis)
    o.tdown = minit(axis)
    o.tlast = minit(axis)
    o.theld = minit(axis)
    o.vinit = minit(axis)
    o.lvl_frame = minit(axis)
    o.lvl_clock = minit(axis)
    o.blank = _obj_:new()

    o.arg_defaults = {
        minit(axis),
        minit(axis),
        nil,
        nil,
        o.list
    }
    
    return v
end

_grid.binary.new = function(self, o) 
    o = _grid.muxaffordance.new(self, o)

    --rawset(o, 'list', {})
    local v = binaryvals(o)

    if type(o.v) ~= 'function' then
        if type(o.v) ~= 'table' or (type(o.v) == 'table' and #o.v ~= #v) then o.v = v end
    end
    
    return o
end

function _grid.binary:clear()
    if type(self.v) ~= 'function' then self.v = binaryvals(self) end
    --self:update() --?
end

_grid.binary.input.muxhandler = rout.binary.input

_grid.binary.output.muxhandler = rout.binary.change

_grid.binary.output.handler = function(s, v)
    return s.muxhandler[redrawfilter(s)](s, v)
end

_grid.binary.output.muxredraw = rout.binary.redraw

_grid.momentary = _grid.binary:new { edge = 'both', persistent = false }

_grid.momentary.input.muxhandler = rout.momentary.input

_grid.toggle = _grid.binary:new { edge = 'rising' }

_grid.toggle.new = function(self, o) 
    o = _grid.binary.new(self, o)

    --rawset(o, 'toglist', {})
    o.toglist = _obj_:new()

    local _, axis = input_contained(o, { -1, -1 })

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

_grid.toggle.input.muxhandler = rout.toggle.input

_grid.trigger = _grid.binary:new { 
    persistent = false,
    edge = 'rising',
    lvl = {
        0,
        function(s, draw)
            draw(15)
            clock.sleep(0.1)
            draw(0)
        end
    }
}

_grid.trigger.new = function(self, o) 
    o = _grid.binary.new(self, o)

    --rawset(o, 'triglist', {})
    o.triglist = _obj_:new()

    local _, axis = input_contained(o, { -1, -1 })
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

_grid.trigger.input.muxhandler = rout.trigger.input
_grid.trigger.output.muxhandler = rout.trigger.redraw

_grid.binary.output.muxhandler.line_y = _grid.binary.output.muxhandler.line_x

_grid.fill = _grid.muxaffordance:new { persistent = false }
_grid.fill.input = nil

_grid.fill.new = function(self, o) 
    o = _grid.muxaffordance.new(self, o)

    local _, axis = input_contained(o, { -1, -1 })
    local v

    if axis.x and axis.y then 
        v = _obj_:new()
        for x = 1, axis.x do 
            v[x] = _obj_:new()
            for y = 1, axis.y do
                v[x][y] = 1
            end
        end
    elseif axis.x or axis.y then
        v = _obj_:new()
        for x = 1, (axis.x or axis.y) do 
            v[x] = 1
        end
    else 
        v = 1
    end


    if type(o.v) ~= 'function' then
        if type(o.v) ~= type(v) then o.v = v
        elseif o.v == 0 then o.v = v end
    end

    return o
end

_grid.fill.output.muxredraw = rout.fill.redraw

_grid.number = _grid.muxaffordance:new { v = 1, edge = 'rising', fingers = nil, tdown = 0, filtersame = true, count = { 1, 1 }, vlast = 1, min = 1, max = math.huge }

_grid.number.new = function(self, o) 
    o = _grid.muxaffordance.new(self, o)

    --rawset(o, 'hlist', {})
    o.hlist = _obj_:new()
    o.count = { 1, 1 }

    local _, axis = input_contained(o, { -1, -1 })
   
    if type(o.v) ~= 'function' then
        if axis.x and axis.y then o.v = type(o.v) == 'table' and o.v or { x = 1, y = 1 } end
        if axis.x and axis.y then o.vlast = type(o.vlast) == 'table' and o.vlast or { x = 1, y = 1 } end
    end

    o.arg_defaults = {
        0,
        0
    }

    return o
end

local input_contained_wrap = function(s, inargs, axis_size)
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

_grid.number.input.filter = function(s, args)
    local contained, axis_size = input_contained(s, args)

    if (s.p_.wrap~=nil) and ((axis_size.x == nil) ~= (axis_size.y == nil)) then
        local cont, i = input_contained_wrap(s, args, axis_size)
        
        if cont then return { "line", i, nil, args[3] } else return end
    end

    if contained then
        if axis_size.x == nil and axis_size.y == nil then
            return { "point", nil, nil, args[3] }
        elseif axis_size.x ~= nil and axis_size.y ~= nil then
            return { "plane", args[1] - s.p_.x[1] + 1, s.p_.y[2] - args[2] + 1, args[3] }
        else
            if axis_size.x ~= nil then
                return { "line", args[1] - s.p_.x[1] + 1, nil, args[3] }
            elseif axis_size.y ~= nil then
                return { "line", s.p_.y[2] - args[2] + 1, nil, args[3] }
            end
        end
    else return nil end
end

_grid.number.input.muxhandler = rout.number.input

_grid.number.output.muxredraw = rout.number.redraw

_grid.control = _grid.number:new { 
    min = 0, max = 1,
    lvl = { 0, 4, 15 },
    step = 0, --0.01,
    v = 0,
    units = '',
    quantum = 0.01,
    warp = 'lin',
    wrap = false,
    controlspec = nil,
    filtersame = false,
}

_grid.control.new = function(self, o)
    local cs = o.controlspec

    o = _grid.affordance.new(self, o)

    local _, axis = input_contained(o, { -1, -1 })
   
    if type(o.v) ~= 'function' then
        if axis.x and axis.y then o.v = type(o.v) == 'table' and o.v or { x = 0, y = 0 } end
    end
    if axis.x and axis.y then o.vlast = type(o.vlast) == 'table' and o.vlast or { x = 0, y = 0 } end
    local default = type(o.p_.v) == 'table' and o.p_.v[1] or o.p_.v

    o.controlspec = cs or controlspec.new(o.p_.min, o.p_.max, o.p_.warp, o.p_.step, default, o.p_.units, o.p_.quantum, o.p_.wrap)

    return o
end

_grid.control.input.muxhandler = rout.control.input

_grid.control.output.muxredraw = rout.control.redraw

_grid.range = _grid.muxaffordance:new { edge = 'rising', fingers = { 2, 2 }, tdown = 0, count = { 1, 1 }, v = { 0, 0 } }

_grid.range.new = function(self, o) 
    o = _grid.muxaffordance.new(self, o)

    --rawset(o, 'hlist', {})
    o.hlist = _obj_:new()
    o.count = { 1, 1 }
    o.fingers = { 1, 1 }
    
    o.arg_defaults = {
        0,
        0
    }

    local _, axis = input_contained(o, { -1, -1 })
 
    if axis.x and axis.y then o.v = type(o.v[1]) == 'table' and o.v or { { x = 0, y = 0 }, { x = 0, y = 0 } } end
 
    return o
end

_grid.range.input.muxhandler = rout.range.input

_grid.range.output.muxredraw = rout.range.redraw

-- grid.pattern, grid.preset ------------------------------------------------------------------------

_grid.pattern = _grid.toggle:new {
    lvl = {
        0, ------------------ 0 empty
        function(s, d) ------ 1 empty, recording, no playback
            while true do
                d(4)
                clock.sleep(0.25)
                d(0)
                clock.sleep(0.25)
            end
        end,
        4, ------------------ 2 filled, paused
        15, ----------------- 3 filled, playback
        function(s, d) ------ 4 filled, recording, playback
            while true do
                d(15)
                clock.sleep(0.2)
                d(0)
                clock.sleep(0.2)
            end
        end,
    },
    edge = 'falling',
    include = function(s, x, y) --limit range based on pattern clear state
        local p
        if x and y then p = s[x][y]
        elseif x then p = s[x]
        else p = s[1] end

        if p.count > 0 then
            --if p.overdub then return { 2, 4 }
            --else return { 2, 3 } end
            return { 2, 3 }
        else
            return { 0, 1 }
        end
    end,
    --clock = true,
    capture = 'input',
    action = function(s, value, time, delta, add, rem, list, last)
        -- assign variables, setter function based on affordance dimentions
        local set, p, v, t, d
        local switch = s.count == 1

        if type(value) == 'table' then
            local i = add or rem
            if i then
                if type(value)[1] == 'table' then
                    p = s[i.x][i.y]
                    t = time[i.x][i.y]
                    d = delta[i.x][i.y]
                    v = value[i.x][i.y]
                    set = function(val)
                        ----- hacks
                        if val == 0 then
                            for j,w in ipairs(s.toglist) do
                                if w.x == i.x and w.y == i.y then 
                                    rem = table.remove(s.toglist, j)
                                end
                            end
                        else
                            if not tab.contains(s.toglist, i) then table.insert(s.toglist, i) end
                            if switch and #s.toglist > 1 then table.remove(s.toglist, 1) end
                        end
                        value[i.x][i.y] = val
                        return value
                    end
                else
                    p = s[i]
                    t = time[i]
                    d = delta[i]
                    v = value[i]
                    set = function(val)
                        ----- hacks
                        if val == 0 then
                            local k = tab.key(s.toglist, i)
                            if k then
                                table.remove(s.toglist, k)
                            end
                        else
                            if not tab.contains(s.toglist, i) then table.insert(s.toglist, i) end
                            if switch and #s.toglist > 1 then table.remove(s.toglist, 1) end
                        end

                        value[i] = val
                        return value
                    end
                end
            end
        else 
            p = s[1] 
            t = time
            d = delta
            v = value
            set = function(val) return value end
        end

        local function stop_all()
            if switch then
                for j,w in ipairs(s) do
                    if w.rec == 1 then w:rec_stop() end
                    w:stop()
                end
                
                if s.stop then s:stop() end
            end
        end

        if p then
            if t > 0.5 then -- hold to clear
                if s.stop then s:stop() end
                p:clear()
                return set(0)
            else
                if p.count > 0 then
                    if d < 0.3 then -- double-tap to overdub
                        p:resume()
                        p:set_overdub(1)
                        return set(4)
                    else
                        if p.rec == 1 then --play pattern / stop recording
                            p:rec_stop()
                            p:start()
                            return set(3)
                        elseif p.overdub == 1 then --stop overdub
                            p:set_overdub(0)
                            return set(3)
                        else
                            --clock.sleep(0.3)

                            if v == 3 then --resume pattern
                                -- if count == 1 then stop all patterns
                                stop_all()

                                p:resume()
                            elseif v == 2 then --pause pattern
                                p:stop() 
                                if s.stop then s:stop() end
                            end
                        end
                    end
                else
                    if v == 1 then --start recording new pattern
                        -- if count == 1 then stop all patterns
                        stop_all()

                        p:rec_start()
                    end
                end
            end
        end
    end
}

_grid.pattern.new = function(self, o) 
    o = _grid.toggle.new(self, o)

    local _, axis = input_contained(o, { -1, -1 })

    -- create pattern per grid key
    if axis.x and axis.y then 
        for x = 1, axis.x do 
            o[x] = nest_ {
                target = function(s)
                    return s.p.target
                end
            }

            for y = 1, axis.y do
                o[x][y] = _pattern:new()
            end
        end
    elseif axis.x or axis.y then
        for x = 1, (axis.x or axis.y) do 
            o[x] = _pattern:new()
        end
    else 
        o[1] = _pattern:new()
    end
    
    return o
end

_grid.preset = _grid.number:new {
    lvl = function(s, x, y)
        local st
        if x and y then st = s[1].state[x][y]
        elseif x then st = s[1].state[x]
        else return { 4, 15 } end

        if st then return { 4, 15 }
        else return { 0, 15 } end
    end,
    action = function(s, v, t, delta)
        if type(s.p_.v) == 'table' then 
            if s[1].state[v.x][v.y] then s[1]:recall(v.x, v.y)
            else s[1]:store(v.x, v.y) end
        else 
            if s[1].state[v] then 
                s[1]:recall(v)
            else 
                s[1]:store(v) 
            end
        end
    end
}

--[[
function _grid.preset:init()
    _grid.toggle.init(self)

    local _, axis = input_contained(self, { -1, -1 })

    if axis.x and axis.y then 
        for x = 1, axis.x do 
            self[1].state[x] = nest_:new()
        end

        self[1]:store(self.p_.v.x, self.p_.v.y)
    else
        print 'store init'
        self[1]:store(self.p_.v)
    end
end
--]]

_grid.preset[1] = _preset:new {
    pass = function(self, sender, v)
        local st
        if type(self.p_.v) == 'table' then st = self.state[self.p_.v.x][self.p_.v.y]
        else st = self.state[self.p_.v] end

        if st then
            local o = nest_.find(st, sender:path(self.p.p_.target or self.p_.target))
            if o then
                o.value = type(v) == 'table' and v:new() or v
            end
        end
    end
}

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
        o.value = function() return params:get(id) end
        o.action = function(s, v) params:set(id, v) end
        s:merge(o)
    end
end

_grid.control.param = function(s, id)
    local p,t = gp(id), '_grid.control'

    if p.t == pt.control then
        lnk(s, id, t, {
            controlspec = p.controlspec,
        })
    else err(t) end; return s
end
_grid.number.param = function(s, id)
    local p,t = gp(id), '_grid.number'

    if p.t == pt.option then
        lnk(s, id, t, {})
    elseif p.t == pt.number then
        lnk(s, id, t, {
            min = p.min, max = p.max
        })
    else err(t) end; return s
end
_grid.toggle.param = function(s, id)
    local p,t = gp(id), '_grid.toggle'

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
_grid.momentary.param = function(s, id)
    local p = gp(id)

    if p.t == pt.binary then
        lnk(s, id, '_grid.momentary', {})
    else err(t) end; return s
end
_grid.trigger.param = function(s, id)
    local p,t = gp(id), '_grid.trigger'

    if p.t == pt.binary then
        if type(s.v) == 'table' then
            print(t .. '.param: value cannot be a table')
        else
            --o.label = (s.label ~= nil) and s.label or gp(id).name or id
            s.action = function(s, v) params:delta(id) end
        end
    else err(t) end; return s
end

return _grid
