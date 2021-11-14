local tab = require 'tabutil'

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

_grid.binary.input.muxhandler = _obj_:new {
    point = function(s, x, y, z, min, max, wrap)
        if z > 0 then 
            s.tlast = s.tdown
            s.tdown = util.time()
        else s.theld = util.time() - s.tdown end
        return z, s.theld
    end,
    line = function(s, i, y, z, min, max, wrap)
        --local i = x - s.p_.x[1] + 1
        local add
        local rem

        if z > 0 then
            add = i
            s.tlast[i] = s.tdown[i]
            s.tdown[i] = util.time()
            table.insert(s.list, i)
            if wrap and #s.list > wrap then rem = table.remove(s.list, 1) end
        else
            -- rem = i ----- negative concequences  ?
            local k = tab.key(s.list, i)
            if k then
                rem = table.remove(s.list, k)
            end
            s.theld[i] = util.time() - s.tdown[i]
        end
        
        if add then s.held[add] = 1 end
        if rem then s.held[rem] = 0 end

        return (#s.list >= min and (max == nil or #s.list <= max)) and s.held or nil, s.theld, nil, add, rem, s.list
    end,
    plane = function(s, x, y, z, min, max, wrap)
        --local i = { x = x - s.p_.x[1] + 1, y = y - s.p_.y[1] + 1 }
        local i = { x = x, y = y }
        local add
        local rem

        if z > 0 then
            add = i
            s.tlast[i.x][i.y] = s.tdown[i.x][i.y]
            s.tdown[i.x][i.y] = util.time()
            table.insert(s.list, i)
            if wrap and (#s.list > wrap) then rem = table.remove(s.list, 1) end
        else
            rem = i
            for j,w in ipairs(s.list) do
                if w.x == i.x and w.y == i.y then 
                    rem = table.remove(s.list, j)
                end
            end
            s.theld[i.x][i.y] = util.time() - s.tdown[i.x][i.y]
        end

        if add then s.held[add.x][add.y] = 1 end
        if rem then s.held[rem.x][rem.y] = 0 end

        --[[
        if (#s.list >= min and (max == nil or #s.list <= max)) then
            return s.held, s.theld, nil, add, rem, s.list
        end
        ]]

        return (#s.list >= min and (max == nil or #s.list <= max)) and s.held or nil, s.theld, nil, add, rem, s.list
    end
}

local lvl = function(s, i, x, y)
    local x = s.p_('lvl', x, y)
    -- come back later and understand or not understand ? :)
    return (type(x) ~= 'table') and ((i > 0) and x or 0) or x[i + 1] or 15
end

_grid.binary.output.muxhandler = _obj_:new {
    point = function(s, v) 
        local lvl = lvl(s, v)
        local d = s.devs.g

        if s.lvl_clock then clock.cancel(s.lvl_clock) end

        if type(lvl) == 'function' then
            s.lvl_clock = clock.run(function()
                lvl(s, function(l)
                    s.lvl_frame = l
                    d.dirty = true
                end)
            end)
        end
    end,
    line_x = function(s, v) 
        local d = s.devs.g
        for x,w in ipairs(v) do 
            local lvl = lvl(s, w, x)
            if s.lvl_clock[x] then clock.cancel(s.lvl_clock[x]) end

            if type(lvl) == 'function' then
                s.lvl_clock[x] = clock.run(function()
                    lvl(s, function(l)
                        s.lvl_frame[x] = l
                        d.dirty = true
                    end)
                end)
            end
        end
    end,
    plane = function(s, v) 
        local d = s.devs.g
        for x,r in ipairs(v) do 
            for y,w in ipairs(r) do 
                local lvl = lvl(s, w, x, y)
                if s.lvl_clock[x][y] then clock.cancel(s.lvl_clock[x][y]) end

                if type(lvl) == 'function' then
                    s.lvl_clock[x][y] = clock.run(function()
                        lvl(s, function(l)
                            s.lvl_frame[x][y] = l
                            d.dirty = true
                        end)
                    end)
                end
            end
        end
    end
}

_grid.binary.output.muxhandler.line_y = _grid.binary.output.muxhandler.line_x

_grid.binary.output.handler = function(s, v)
    return s.muxhandler[redrawfilter(s)](s, v)
end

_grid.binary.output.muxredraw = _obj_:new {
    point = function(s, g, v)
        local lvl = lvl(s, v)

        if type(lvl) == 'function' then lvl = s.lvl_frame end
        if lvl > 0 then g:led(s.p_.x, s.p_.y, lvl) end
    end,
    line_x = function(s, g, v)
        for x,l in ipairs(v) do 
            local lvl = lvl(s, l, x)
            if type(lvl) == 'function' then lvl = s.lvl_frame[x] end
            if lvl > 0 then g:led(x + s.p_.x[1] - 1, s.p_.y, lvl) end
        end
    end,
    line_y = function(s, g, v)
        for y,l in ipairs(v) do 
            local lvl = lvl(s, l, y)
            if type(lvl) == 'function' then lvl = s.lvl_frame[y] end
            if lvl > 0 then g:led(s.p_.x, s.p_.y[2] - y + 1, lvl) end
        end
    end,
    plane = function(s, g, v)
        for x,r in ipairs(v) do 
            for y,l in ipairs(r) do 
                local lvl = lvl(s, l, x, y)
                if type(lvl) == 'function' then lvl = s.lvl_frame[x][y] end
                if lvl > 0 then g:led(x + s.p_.x[1] - 1, s.p_.y[2] - y + 1, lvl) end
            end
        end
    end
}

_grid.momentary = _grid.binary:new { edge = 'both', persistent = false }

local function count(s) 
    local min = 0
    local max = nil

    if type(s.p_.count) == "table" then 
        max = s.p_.count[#s.p_.count]
        min = #s.p_.count > 1 and s.p_.count[1] or 0
    else max = s.p_.count end

    return min, max
end

local function fingers(s)
    local min = 0
    local max = math.huge

    if type(s.p_.fingers) == "table" then 
        max = s.p_.fingers[#s.p_.fingers]
        min = #s.p_.fingers > 1 and s.p_.fingers[1] or 0
    else max = s.p_.fingers or max end

    return min, max
end

_grid.momentary.input.muxhandler = _obj_:new {
    point = function(s, x, y, z)
        return _grid.binary.input.muxhandler.point(s, x, y, z)
    end,
    line = function(s, x, y, z)
        local max
        local min, wrap = count(s)
        if s.fingers then
            min, max = fingers(s)
        end        

        local v,t,last,add,rem,list = _grid.binary.input.muxhandler.line(s, x, y, z, min, max, wrap)
        if v then
            return v,t,last,add,rem,list
        else
            return s.vinit, s.vinit, nil, nil, nil, s.blank
        end
    end,
    plane = function(s, x, y, z)
        local max
        local min, wrap = count(s)
        if s.fingers then
            min, max = fingers(s)
        end        

        local v,t,last,add,rem,list = _grid.binary.input.muxhandler.plane(s, x, y, z, min, max, wrap)
        if v then
            return v,t,last,add,rem,list
        else
            return s.vinit, s.vinit, nil, nil, nil, s.blank
        end
    end
}

local edge = { rising = 1, falling = 0, both = 2 }

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

local function toggle(s, value, lvl, range, include)
    local function delta(vvv)
        local v = (vvv + 1) % (((type(lvl) == 'table') and #lvl > 1) and (#lvl) or 2)

        if range[1] and range[2] then
            while v > range[2] do
                v = v - (range[2] - range[1]) - 1
            end
            while v < range[1] do
                v = v + (range[2] - range[1]) + 1
            end
        end

        return v
    end

    local vv = delta(value)

    if include then
        local i = 0
        while not tab.contains(include, vv) do
            vv = delta(vv)
            i = i + 1
            if i > 64 then break end -- seat belt
        end
    end

    return vv
end

local function togglelow(s, range, include)
    if range[1] and range[2] and include then
        return math.max(range[1], include[1])
    elseif (range[1] and range[2]) or include then
        return range[1] or include[1]
    else return 0 end
end

local function toggleset(s, v, lvl, range, include)      
    if range[1] and range[2] then
        while v > range[2] do
            v = v - (range[2] - range[1]) - 1
        end
        while v < range[1] do
            v = v + (range[2] - range[1]) + 1
        end
    end

    if include then
        local i = 0
        while not tab.contains(include, v) do
            v = toggle(s, v, lvl, range, include)
            i = i + 1
            if i > 64 then break end -- seat belt
        end
    end

    return v
end

_grid.toggle.input.muxhandler = _obj_:new {
    point = function(s, x, y, z)
        local held = _grid.binary.input.muxhandler.point(s, x, y, z)
        local e = edge[s.p_.edge]

        if e == held or (held == 1 and e == 2) then
            return toggle(s, s.p_.v, s.p_.lvl,  { s.p_.min, s.p_.max }, s.p_.include),
                s.theld,
                util.time() - s.tlast
        elseif e == 2 then
            return s.p_.v, s.theld, util.time() - s.tlast
        end
    end,
    line = function(s, x, y, z)
        local held, theld, _, hadd, hrem, hlist = _grid.binary.input.muxhandler.line(s, x, y, z, 0, nil)
        local min, max = count(s)
        local i
        local add
        local rem
        local e = edge[s.p_.edge]
       
        if e > 0 and hadd then i = hadd end
        if e == 0 and hrem then i = hrem end

        if fingers and e == 0 then
            local fmin, fmax = fingers(s)

            if hrem then
                if #hlist+1 >= fmin and #hlist+1 <= fmax then
                    local function tog(ii)
                        local range = { s.p_('min', ii), s.p_('max', ii) }
                        local include = s.p_('include', ii)
                        local low = togglelow(s, range, include)

                        s.p_.v[ii] = toggle(
                            s, 
                            s.p_.v[ii], 
                            s.p_('lvl', ii),
                            range,
                            include
                        ) 
                        s.ttog[ii] = util.time() - s.tlast[ii]

                        if s.p_.v[ii] > low then
                            if not tab.contains(s.toglist, ii) then table.insert(s.toglist, ii) end
                            if max and #s.toglist > max then rem = table.remove(s.toglist, 1) end
                        else 
                            rem = ii
                            local k = tab.key(s.toglist, ii)
                            if k then
                                rem = table.remove(s.toglist, k)
                            end
                        end
                    end

                    add = hrem
                    tog(hrem)
                    for j,w in ipairs(hlist) do tog(w) end
                    
                    s:replace('list', {})

                    return s.p_.v, theld, s.ttog, add, rem, s.toglist
                else
                    s:replace('list', {})
                end
            end
        else
            if i then   
                if #s.toglist >= min then
                    local range = { s.p_('min', i), s.p_('max', i) }
                    local include = s.p_('include', i)
                    local v = toggle(
                        s, 
                        s.p_.v[i], 
                        lvl,
                        range,
                        include
                    )
                    local low = togglelow(s, range, include)
                    
                    if v > low then
                        add = i
                        
                        if not tab.contains(s.toglist, i) then table.insert(s.toglist, i) end
                        if max and #s.toglist > max then rem = table.remove(s.toglist, 1) end
                    else 
                        rem = i
                        local k = tab.key(s.toglist, i)
                        if k then
                            rem = table.remove(s.toglist, k)
                        end
                    end
                
                    s.ttog[i] = util.time() - s.tlast[i]

                    if add then s.p_.v[add] = v end
                    if rem then s.p_.v[rem] = togglelow(s, { s.p_('min', rem), s.p_('max', rem) }, s.p_('include', rem)) end

                else
                    local hhlist = _obj_ {}
                    if hrem then
                        for j, w in ipairs(hlist) do hhlist[j] = w end
                        table.insert(hhlist, hrem)
                    else hhlist = hlist end

                    if #hhlist >= min then
                        for j,w in ipairs(hhlist) do
                            s.toglist[j] = w
                            s.p_.v[w] = toggleset(s, 1, s.p_('lvl', w), { s.p_('min', w), s.p_('max', w) }, s.p_('include', w))
                        end
                    end
                end
                
                if #s.toglist < min then
                    for j,w in ipairs(s.p_.v) do s.p_.v[j] = togglelow(s, { s.p_('min', j), s.p_('max', j) }, s.p_('include', j)) end
                    --s.toglist = {}
                    s:replace('toglist', {})
                end

                return s.p_.v, theld, s.ttog, add, rem, s.toglist
            elseif e == 2 then
                return s.p_.v, theld, s.ttog, nil, nil, s.toglist
            end
        end
    end,
    --TODO: copy over changes in line
    plane = function(s, x, y, z)
        local held, theld, _, hadd, hrem, hlist = _grid.binary.input.muxhandler.plane(s, x, y, z, 0, nil)
        local min, max = count(s)
        local i
        local add
        local rem
        local e = edge[s.p_.edge]
       
        if e > 0 and hadd then i = hadd end
        if e == 0 and hrem then i = hrem end
        
        if i and held then   
            if #s.toglist >= min then
                local lvl = s.p_('lvl', i.x, i.y)
                local range = { s.p_('min', i.x, i.y), s.p_('max', i.x, i.y) }
                local include = s.p_('include', i.x, i.y)
                local v = toggle(
                    s, 
                    s.p_.v[i.x][i.y], 
                    lvl,
                    range,
                    include
                )
                local low = togglelow(s, range, include)
                
                if v > low then
                    add = i
                    
                    local contains = false
                    for j,w in ipairs(s.toglist) do
                        if w.x == i.x and w.y == i.y then 
                            contains = true
                            break
                        end
                    end
                    if not contains then table.insert(s.toglist, i) end
                    if max and #s.toglist > max then rem = table.remove(s.toglist, 1) end
                else 
                    rem = i
                    for j,w in ipairs(s.toglist) do
                        if w.x == i.x and w.y == i.y then 
                            rem = table.remove(s.toglist, j)
                        end
                    end
                end
            
                s.ttog[i.x][i.y] = util.time() - s.tlast[i.x][i.y]

                if add then s.p_.v[add.x][add.y] = v end
                if rem then s.p_.v[rem.x][rem.y] = togglelow(s, { s.p_('min', rem.x, rem.y), s.p_('max', rem.x, rem.y) }, s.p_('include', rem.x, rem.y)) end

            elseif #hlist >= min then
                for j,w in ipairs(hlist) do
                    s.toglist[j] = w
                    s.p_.v[w.x][w.y] = toggleset(s, 1, s.p_('lvl', w.x, w.y), { s.p_('min', w.x, w.y), s.p_('max', w.x, w.y) }, s.p_('include', w.x, w.y))
                end
            end

            if #s.toglist < min then
                for x,w in ipairs(s.p_.v) do 
                    for y,_ in ipairs(w) do
                        s.p_.v[x][y] = low
                    end
                end
                --s.toglist = {}
                s:replace('toglist', {})
            end

            return s.p_.v, theld, s.ttog, add, rem, s.toglist
        elseif e == 2 then
            return s.p_.v, theld, s.ttog, nil, nil, s.toglist
        end
    end
}

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

_grid.trigger.input.muxhandler = _obj_:new {
    point = function(s, x, y, z)
        local held = _grid.binary.input.muxhandler.point(s, x, y, z)
        local e = edge[s.p_.edge]
        
        if e == held then
            return 1, s.theld, util.time() - s.tlast
        end
    end,
    line = function(s, x, y, z)
        local min, max = count(s)
        local held, theld, _, hadd, hrem, hlist = _grid.binary.input.muxhandler.line(s, x, y, z, 0, nil)
        local ret = false
        local lret, add
        local e = edge[s.p_.edge]

        if fingers and e == 0 then
            local fmin, fmax = fingers(s)
            fmin = math.max(fmin, min)

            if hrem then
                if #hlist+1 >= fmin and #hlist+1 <= fmax then
                    s:replace('triglist', {})

                    if s.p_.v[hrem] <= 0 then
                        add = hrem
                        s.p_.v[hrem] = 1 
                        s.tdelta[hrem] = util.time() - s.tlast[hrem]
                        table.insert(s.triglist, hrem)
                    end

                    --this is gonna kinda remove indicies randomly when getting over max
                    --oh well
                    for i,w in ipairs(hlist) do if max and (i+1 <= max) then
                        if s.p_.v[w] <= 0 then
                            s.p_.v[w] = 1
                            s.tdelta[w] = util.time() - s.tlast[w]
                            table.insert(s.triglist, w)
                        end
                    end end
                    
                    s:replace('list', {})

                    return s.p_.v, s.theld, s.tdelta, add, nil, s.triglist
                else
                    s:replace('list', {})
                end
            end
        else
            if e == 1 and #hlist > min and (max == nil or #hlist <= max) and hadd then
                s.p_.v[hadd] = 1
                s.tdelta[hadd] = util.time() - s.tlast[hadd]

                ret = true
                add = hadd
                lret = hlist
            elseif e == 1 and #hlist == min and hadd then
                for i,w in ipairs(hlist) do 
                    s.p_.v[w] = 1

                    s.tdelta[w] = util.time() - s.tlast[w]
                end

                ret = true
                lret = hlist
                add = hlist[#hlist]

            elseif e == 0 and #hlist >= min - 1 and (max == nil or #hlist <= max - 1)and hrem and not hadd then
                --s.triglist = {}
                s:replace('triglist', {})

                for i,w in ipairs(hlist) do 
                    if s.p_.v[w] <= 0 then
                        s.p_.v[w] = 1
                        s.tdelta[w] = util.time() - s.tlast[w]
                        table.insert(s.triglist, w)
                    end
                end
                
                if s.p_.v[hrem] <= 0 then
                    ret = true
                    lret = s.triglist
                    add = hrem
                    s.p_.v[hrem] = 1 
                    s.tdelta[hrem] = util.time() - s.tlast[hrem]
                    table.insert(s.triglist, hrem)
                end
            end
                
            if ret then return s.p_.v, s.theld, s.tdelta, add, nil, lret end
        end
    end,
    --TODO: copy new changes from line
    plane = function(s, x, y, z)
        local max
        local min, max = count(s)
        if s.fingers then
            min, max = fingers(s)
        end        
        local held, theld, _, hadd, hrem, hlist = _grid.binary.input.muxhandler.plane(s, x, y, z, 0, nil)
        local ret = false
        local lret, add
        local e = edge[s.p_.edge]

        if e == 1 and #hlist > min and (max == nil or #hlist <= max) and hadd then
            s.p_.v[hadd.x][hadd.y] = 1
            s.tdelta[hadd.x][hadd.y] = util.time() - s.tlast[hadd.x][hadd.y]

            ret = true
            add = hadd
            lret = hlist
        elseif e == 1 and #hlist == min and hadd then
            for i,w in ipairs(hlist) do 
                s.p_.v[w.x][w.y] = 1

                s.tdelta[w.x][w.y] = util.time() - s.tlast[w.x][w.y]
            end

            ret = true
            add = hlist[#hlist]
            lret = hlist
        elseif e == 0 and #hlist >= min - 1 and (max == nil or #hlist <= max - 1)and hrem and not hadd then
            --s.triglist = {}
            s:replace('triglist', {})

            for i,w in ipairs(hlist) do 
                if s.p_.v[w.x][w.y] <= 0 then
                    s.p_.v[w.x][w.y] = 1
                    s.tdelta[w.x][w.y] = util.time() - s.tlast[w.x][w.y]
                    table.insert(s.triglist, w)
                end
            end
            
            if s.p_.v[hrem.x][hrem.y] <= 0 then
                ret = true
                lret = s.triglist
                add = hrem
                s.p_.v[hrem.x][hrem.y] = 1 
                s.tdelta[hrem.x][hrem.y] = util.time() - s.tlast[hrem.x][hrem.y]
                table.insert(s.triglist, hrem)
            end
        end
            
        if ret then return s.p_.v, s.theld, s.tdelta, add, nil, lret end
    end
}

_grid.trigger.output.muxhandler = _obj_:new {
    point = function(s, v) 
        local lvl = lvl(s, v)
        local d = s.devs.g

        if s.lvl_clock then clock.cancel(s.lvl_clock) end

        if type(lvl) == 'function' then
            s.lvl_clock = clock.run(function()
                lvl(s, function(l)
                    s.lvl_frame = l
                    d.dirty = true
                end)

                --if type(s.p_.v) ~= 'function' then s.p_.v = 0 end -------------------
            end)
        end
    end,
    line_x = function(s, v) 
        local d = s.devs.g
        for x,w in ipairs(v) do 
            local lvl = lvl(s, w, x)
            if s.lvl_clock[x] then clock.cancel(s.lvl_clock[x]) end

            if type(lvl) == 'function' then
                s.lvl_clock[x] = clock.run(function()
                    lvl(s, function(l)
                        s.lvl_frame[x] = l
                        d.dirty = true
                    end)
                        
                    s.p_.v[x] = 0
                end)
            end
        end
    end,
    plane = function(s, v) 
        local d = s.devs.g
        for x,r in ipairs(v) do 
            for y,w in ipairs(r) do 
                local lvl = lvl(s, w, x, y)
                if s.lvl_clock[x][y] then clock.cancel(s.lvl_clock[x][y]) end

                if type(lvl) == 'function' then
                    s.lvl_clock[x][y] = clock.run(function()
                        lvl(s, function(l)
                            s.lvl_frame[x][y] = l
                            d.dirty = true
                        end)
                                
                        s.p_.v[x][y] = 0
                    end)
                end
            end
        end
    end
}

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

_grid.fill.output.muxredraw = _obj_:new {
    point = _grid.binary.output.muxredraw.point,
    line_x = _grid.binary.output.muxredraw.line_x,
    line_y = _grid.binary.output.muxredraw.line_y,
    plane = _grid.binary.output.muxredraw.plane
}

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

_grid.number.input.muxhandler = _obj_:new {
    point = function(s, x, y, z) 
        if z > 0 then return 0 end
    end,
    line = function(s, i, _, z) 
        --local i = x - s.p_.x[1] + 1
        local min, max = fingers(s)
        local m = ((s.p_.controlspec and s.p_.controlspec.minval) or s.p_.min or 1) - 1
        local e = edge[s.p_.edge]

        if z > 0 then
            if #s.hlist == 0 then s.tdown = util.time() end
            table.insert(s.hlist, i)
           
            if e > 0 then 
                if (i+m) ~= s.p_.v or (not s.filtersame) then 
                    local len = #s.hlist
                    --s.hlist = {}
                    s:replace('hlist', {})

                    if max == nil or len <= max then
                        s.vlast = s.p_.v
                        return i+m, len > 1 and util.time() - s.tdown or 0, i+m - s.vlast, i+m
                    end
                elseif e == 2 then
                    return i+m, 0, i+m - s.vlast, i+m
                end
            end
        else
            if e == 0 then
                if #s.hlist >= min then
                    i = s.hlist[#s.hlist]
                    local len = #s.hlist
                    --s.hlist = {}
                    s:replace('hlist', {})

                    if max == nil or len <= max then
                        if (i+m) ~= s.p_.v or (not s.filtersame) then 
                            s.vlast = s.p_.v
                            return i+m, util.time() - s.tdown, i - s.vlast-m
                        end
                    end
                else
                    local k = tab.key(s.hlist, i)
                    if k then
                        table.remove(s.hlist, k)
                    end
                end
            elseif e == 2 then
                --if i ~= s.p_.v or (not s.filtersame) then 
                s:replace('hlist', {})
                    --if i ~= s.p_.v then 
                return i+m, 0, i+m - s.vlast, nil, i+m
                    --end
                --end
            end
        end
    end,
    plane = function(s, x, y, z) 
        --local i = { x = x - s.p_.x[1] + 1, y = y - s.p_.y[1] + 1 }
        local i = _obj_ { x = x, y = y }
        local e = edge[s.p_.edge]

        local min, max = fingers(s)
        local m = ((s.p_.controlspec and s.p_.controlspec.minval) or s.p_.min or 1) - 1
        m = type(m) ~= 'table' and { m, m } or m
        for i,v in ipairs(m) do m[i] = v - 1 end

        if z > 0 then
            if #s.hlist == 0 then s.tdown = util.time() end
            table.insert(s.hlist, i)
           
            if e > 0 then 
                local len = #s.hlist
                if (
                    not ((i.x+m[1]) == s.p_.v.x and (i.y+m[2]) == s.p_.v.y)
                    ) or (not s.filtersame) 
                then 
                    --s.hlist = {}
                    s:replace('hlist', {})
                    s.vlast.x = s.p_.v.x
                    s.vlast.y = s.p_.v.y
                    s.p_.v.x = i.x + m[1]
                    s.p_.v.y = i.y + m[2]

                    if max == nil or len <= max then
                        return s.p_.v, len > 1 and util.time() - s.tdown or 0, _obj_ { s.p_.v.x - s.vlast.x, s.p_.v.y - s.vlast.y }, i
                    end
                elseif e == 2 then
                    -- if max == nil or len <= max then
                        return s.p_.v, 0, _obj_ { s.p_.v.x - s.vlast.x, s.p_.v.y - s.vlast.y }, i
                    -- end
                end
            end
        else
            if e == 0 then
                if #s.hlist >= min then
                    --i = s.hlist[#s.hlist] or i
                    local len = #s.hlist
                    --s.hlist = {}
                    s:replace('hlist', {})

                    if max == nil or len <= max then
                        if (
                            not ((i.x+m[1]) == s.p_.v.x and (i.y+m[2]) == s.p_.v.y)
                            ) or (not s.filtersame) 
                        then 
                            s.vlast.x = s.p_.v.x
                            s.vlast.y = s.p_.v.y
                            s.p_.v.x = i.x + m[1]
                            s.p_.v.y = i.y + m[2]
                            return s.p_.v, util.time() - s.tdown, _obj_ { s.p_.v.x - s.vlast.x, s.p_.v.y - s.vlast.y }
                        end
                    end
                else
                    for j,w in ipairs(s.hlist) do
                        if w.x == i.x and w.y == i.y then 
                            table.remove(s.hlist, j)
                        end
                    end
                end
            elseif e == 2 then
                s:replace('hlist', {})
                -- if (i.x == s.p_.v.x and i.y == s.p_.v.y) then
                    return s.p_.v, util.time() - s.tdown, _obj_ { s.p_.v.x - s.vlast.x, s.p_.v.y - s.vlast.y }, nil, i
                -- end
            end
        end
    end
}

_grid.number.output.muxredraw = _obj_:new {
    point = function(s, g, v)
        local lvl = lvl(s, 1)
        if lvl > 0 then g:led(s.p_.x, s.p_.y, lvl) end
    end,
    line_x = function(s, g, v)
        for i = 1, s.p_.x[2] - s.p_.x[1] + 1 do
            local lvl = lvl(s, s.p_.v - s.p_.min + 1 == i and 1 or 0, i)
            local x,y,w = i, 1, s.p_.wrap
            if s.p_.wrap then
                x = (i-1)%w + 1
                y = (i-1)//w + 1
            end
            if lvl > 0 then g:led(x + s.p_.x[1] - 1, y + s.p_.y - 1, lvl) end
        end
    end,
    --TODO: wrap
    line_y = function(s, g, v)
        for i = 1, s.p_.y[2] - s.p_.y[1] + 1 do
            local lvl = lvl(s, (s.p_.v - s.p_.min + 1 == i) and 1 or 0, i)
            if lvl > 0 then g:led(s.p_.x, s.p_.y[2] - i + 1, lvl) end
        end
    end,
    plane = function(s, g, v)
        local m = ((s.p_.controlspec and s.p_.controlspec.minval) or s.p_.min or 1) - 1
        m = type(m) ~= 'table' and { m, m } or m
        for i = s.p_.x[1], s.p_.x[2] do
            for j = s.p_.y[1], s.p_.y[2] do
                local li, lj = i - s.p_.x[1] + 1, s.p_.y[2] - j + 1
                local l = lvl(s, ((s.p_.v.x+m[1] == li) and (s.p_.v.y+m[2] == lj)) and 1 or 0, li, lj)
                if l > 0 then g:led(i, j, l) end
            end
        end
    end
}

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

_grid.control.input.muxhandler = _obj_:new {
    point = function(s, x, y, z) 
        return _grid.number.input.muxhandler.point(s, x, y, z)
    end,
    line = function(s, x, y, z) 
        local v,t,d = _grid.number.input.muxhandler.line(s, x, y, z)
        if v then
            local r = type(s.x) == 'table' and s.x or s.y
            local vv = (v - s.p_.controlspec.minval) / (r[2] - r[1])

            local c = s.p_.controlspec:map(vv)
            if s.p_.v ~= c then
                return c, t, d
            end
        end
    end,
    plane = function(s, x, y, z) 
        local v,t,d = _grid.number.input.muxhandler.plane(s, x, y, z)
        if v then
            local ret = false
            for _,k in ipairs { 'x', 'y' } do
                local r = s[k]
                local vv = (v[k] - s.p_.controlspec.minval) / (r[2] - r[1])

                local c = s.p_.controlspec:map(vv)
                if s.p_.v[k] ~= c then
                    ret = true
                    s.p_.v[k] = c
                end
            end

            if ret then return s.p_.v, t, d end
        end
    end
}

_grid.control.output.muxredraw = _obj_:new {
    point = function(s, g, v)
        local lvl = lvl(s, 1)
        if lvl > 0 then g:led(s.p_.x, s.p_.y, lvl) end
    end,
    line_x = function(s, g, v)
        for i = s.p_.x[1], s.p_.x[2] do
            local l = lvl(s, 0)
            local vv = (i - s.p_.x[1]) / (s.p_.x[2] - s.p_.x[1])
            local m = s.p_.controlspec:map(vv)
            if m == v then l = lvl(s, 2)
            elseif m > v and m <= 0 then l = lvl(s, 1)
            elseif m < v and m >= 0 then l = lvl(s, 1) end
            if l > 0 then g:led(i, s.p_.y, l) end
        end
    end,
    line_y = function(s, g, v)
        for i = s.p_.y[1], s.p_.y[2] do
            local l = lvl(s, 0)
            local vv = (i - s.p_.y[1]) / (s.p_.y[2] - s.p_.y[1])
            local m = s.p_.controlspec:map(vv)
            if m == v then l = lvl(s, 2)
            elseif m > v and m <= 0 then l = lvl(s, 1)
            elseif m < v and m >= 0 then l = lvl(s, 1) end
            if l > 0 then g:led(s.p_.x, s.p_.y[2] - i + s.p_.y[1], l) end
        end
    end,
    plane = function(s, g, v)
        local cs = s.p_.controlspec
        for i = s.p_.x[1], s.p_.x[2] do
            for j = s.p_.y[1], s.p_.y[2] do
                local l = lvl(s, 0)
                local m = {
                    x = cs:map((i - s.p_.x[1]) / (s.p_.x[2] - s.p_.x[1])),
                    y = cs:map(((s.p_.y[2] - j + 2) - s.p_.y[1]) / (s.p_.y[2] - s.p_.y[1])),
                }
                if m.x == v.x and m.y == v.y then l = lvl(s, 2)
                --[[

                alt draw method:

                elseif m.x >= v.x and m.y >= v.y and m.x <= 0 and m.y <= 0 then l = lvl(s, 1)
                elseif m.x >= v.x and m.y <= v.y and m.x <= 0 and m.y >= 0 then l = lvl(s, 1)
                elseif m.x <= v.x and m.y <= v.y and m.x >= 0 and m.y >= 0 then l = lvl(s, 1)
                elseif m.x <= v.x and m.y >= v.y and m.x >= 0 and m.y <= 0 then l = lvl(s, 1)

                ]]
                elseif m.x == cs.minval or m.y == cs.minval or m.x == cs.maxval or m.y == cs.maxval then l = lvl(s, 1)
                elseif m.x == 0 or m.y == 0 then l = lvl(s, 1)
                end
                if l > 0 then g:led(i, j, l) end
            end
        end
    end
}

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

_grid.range.input.muxhandler = _obj_:new {
    point = function(s, x, y, z) 
        if z > 0 then return 0 end
    end,
    line = function(s, i, _, z) 
        local e = edge[s.p_.edge]
        --local i = x - s.p_.x[1]

        if z > 0 then
            if #s.hlist == 0 then s.tdown = util.time() end
            table.insert(s.hlist, i)
           
            if e == 1 then 
                if #s.hlist >= 2 then 
                    local v = _obj_ { s.hlist[1], s.hlist[#s.hlist] }
                    table.sort(v)
                    --s.hlist = {}
                    s:replace('hlist', {})
                    return v, util.time() - s.tdown 
                end
            end
        else
            if #s.hlist >= 2 then 
                if e == 0 then
                    local v = _obj_ { s.hlist[1], s.hlist[#s.hlist] }
                    table.sort(v)
                    --s.hlist = {}
                    s:replace('hlist', {})
                    return v, util.time() - s.tdown 
                end
            else
                local k = tab.key(s.hlist, i)
                if k then
                    table.remove(s.hlist, k)
                end
            end
        end
    end,
    plane = function(s, x, y, z) 
        --local i = { x = x - s.p_.x[1], y = y - s.p_.y[1] }
        i = { x = x, y = y }
        local e = edge[s.p_.edge]

        if z > 0 then
            if #s.hlist == 0 then s.tdown = util.time() end
            table.insert(s.hlist, i)
           
            if e == 1 then 
                if #s.hlist >= 2 then 
                    local v = _obj_ { s.hlist[1], s.hlist[#s.hlist] }
                    table.sort(v, function(a, b) 
                        return a.x < b.x
                    end)
                    --s.hlist = {}
                    s:replace('hlist', {})
                    return v, util.time() - s.tdown 
                end
            end
        else
            if #s.hlist >= 2 then 
                if e == 0 then
                    local v = _obj_ { s.hlist[1], s.hlist[#s.hlist] }
                    table.sort(v, function(a, b) 
                        return a.x < b.x
                    end)
                    --s.hlist = {}
                    s:replace('hlist', {})
                    return v, util.time() - s.tdown 
                end
            else
                for j,w in ipairs(s.hlist) do
                    if w.x == i.x and w.y == i.y then 
                        table.remove(s.hlist, j)
                    end
                end
            end
        end
    end
}

_grid.range.output.muxredraw = _obj_:new {
    point = function(s, g, v)
        local lvl = lvl(s, 1)
        if lvl > 0 then g:led(s.p_.x, s.p_.y, lvl) end
    end,
    line_x = function(s, g, v)
        for i = 1, s.p_.x[2] - s.p_.x[1] + 1 do
            local l = lvl(s, 0)
            if i >= v[1] and i <= v[2] then l = lvl(s, 1) end
            if l > 0 then g:led(i + s.p_.x[1] - 1, s.p_.y, l) end
        end
    end,
    line_y = function(s, g, v)
        for i = 1, s.p_.y[2] - s.p_.y[1] + 1 do
            local l = lvl(s, 0)
            if i >= v[1] and i <= v[2] then l = lvl(s, 1) end
            if l > 0 then g:led(s.p_.x, s.p_.y[2] - i + 1, l) end
        end
    end,
    plane = function(s, g, v)
        for i = 1, s.p_.x[2] - s.p_.x[1] + 1 do
            for j = 1, s.p_.y[2] - s.p_.y[1] + 1 do
                local l = lvl(s, 0)
                if (i == v[1].x or i == v[2].x) and j >= v[1].y and j <= v[2].y then l = lvl(s, 1)
                elseif (j == v[1].y or j == v[2].y) and i >= v[1].x and i <= v[2].x then l = lvl(s, 1)
                elseif v[2].y < v[1].y and (i == v[1].x or i == v[2].x) and j >= v[2].y and j <= v[1].y then l = lvl(s, 1)
                end
                if l > 0 then g:led(i + s.p_.x[1] - 1, s.p_.y[2] - j + 1, l) end
            end
        end
    end
}

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
