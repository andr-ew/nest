-- _obj_ is a base object for all the types on this page that impliments concatenative prototypical inheritance. all subtypes of _obj_ have proprer copies of the tables in the prototype rather than delegated pointers, so changes to subtype members will never propogate up the tree

-- GOTCHA: overwriting an existing table value will not format type. instead, use :replace()

local tab = require 'tabutil'

local function formattype(t, k, v, clone_type) 
    if type(v) == "table" then
        if v.is_obj then 
            v._.p = t
            v._.k = k
        elseif not v.new then -- test !
            v = clone_type:new(v)
            v._.p = t
            v._.k = k
        end

        for i,w in ipairs(t._.zsort) do 
            if w.k == k then table.remove(t._.zsort, i) end
        end
        
        t._.zsort[#t._.zsort + 1] = v
    end

    return v
end

local function zcomp(a, b) 
    if type(a) == 'table' and type(b) == 'table' and a.z and b.z then
        return a.z > b.z 
    else return false end
end

local function nickname(k) 
    if k == 'v' then return 'value' else return k end
end

local function index_nickname(t, k) 
    if k == 'v' then return t.value end
end

local function format_nickname(t, k, v) 
    if k == 'v' and not rawget(t, 'value') then
        rawset(t, 'value', v)
        t['v'] = nil
    end
    
    return v
end

_obj_ = {
    print = function(self) print(tostring(self)) end,
    replace = function(self, k, v)
        rawset(self, k, formattype(self, k, v, self._.clone_type))
    end,
    copy = function(self, o) 
        for k,v in pairs(self) do 
            if not rawget(o, k) then
                --if type(v) == "function" then
                    -- function pointers are not copied, instead they are referenced using metatables only when the objects are heierchachically related
                --else
                if type(v) == "table" and v.is_obj then
                    local clone = self[k]:new()
                    o[k] = formattype(o, k, clone, o._.clone_type) ----
                else rawset(o,k,v) end 
            end
        end

        table.sort(o._.zsort, zcomp)

        return o
    end
}

function _obj_:new(o, clone_type)
    local _ = { -- the "instance table" - useful as it is ignored by the inheritance rules, and also hidden in subtables
        is_obj = true,
        p = nil,
        k = nil,
        z = 0,
        zsort = {}, -- list of obj children sorted by descending z value
        clone_type = clone_type,
    }

    o = o or {}
    _.clone_type = _.clone_type or _obj_

    setmetatable(o, {
        __index = function(t, k)
            if k == "_" then return _
            elseif index_nickname(t,k) then return index_nickname(t,k)
            elseif _[k] ~= nil then return _[k]
            --elseif self[k] ~= nil then return self[k]
            else return nil end
        end,
        __newindex = function(t, k, v)
            if _[k] ~= nil then rawset(_,k,v) 
            elseif index_nickname(t, k) then
                rawset(t, nickname(k), formattype(t, nickname(k), v, _.clone_type)) 
            else
                rawset(t, k, formattype(t, k, v, _.clone_type)) 
                
                table.sort(_.zsort, zcomp)
            end
        end,
        __concat = function (n1, n2)
            for k, v in pairs(n2) do
                n1[k] = v
            end
            return n1
        end,
        __call = function(idk, ...) -- dunno what's going on w/ the first arg to this metatmethod
            return o:new(...)
        end,
        --__tostring = function(t) return tostring(t.k) end
    })

    --[[
    
    the parameter proxy table - when accesed this empty table aliases to the object, but if the accesed member is a function, the return value of the function is returned, rather than the function itself

    ]]
    _.p_ = {}

    local function resolve(s, f) 
        if type(f) == 'function' then
            return resolve(s, f(s))
        else return f end
    end

    setmetatable(_.p_, {
        __index = function(t, k) 
            if o[k] then
                return resolve(o, o[k])
            end
        end,
        __newindex = function(t, k, v) o[k] = v end
    })
    
    for k,v in pairs(o) do 
        formattype(o, k, v, _.clone_type) 
        format_nickname(o, k, v)
    end

    self:copy(o)

    return o
end

_input = _obj_:new {
    is_input = true,
    handler = nil,
    devk = nil,
    filter = function(self, devk, args) return args end,
    update = function(self, devk, args, mc)
        if (self.enabled == nil or self.p_.enabled == true) and self.devk == devk then
            local hargs = self:filter(args)
            
            if hargs ~= nil and self.affordance then
                if self.devs[self.devk] then self.devs[self.devk].dirty = true end
 
                if self.handler then 
                    local aargs = table.pack(self:handler(table.unpack(hargs)))

                    if aargs[1] then 
                        self.affordance.v = self.action and self.action(self.affordance or self, table.unpack(aargs)) or aargs[1]

                        if self.metaaffordances_enabled then
                            for i,w in ipairs(mc) do
                                w:pass(self.affordance, self.affordance.v, aargs)
                            end
                        end
                    end
                end
            end
        elseif devk == nil or args == nil then -- called w/o arguments
            local defaults = self.arg_defaults or {}
            self.affordance.v = self.action and self.action(self.affordance or self, self.affordance.v, table.unpack(defaults)) or self.affordance.v
            
            if self.devs[self.devk] then self.devs[self.devk].dirty = true end

            return self.affordance.v
        end
    end
}

function _input:new(o)
    o = _obj_.new(self, o, _obj_)
    local _ = o._

    _.affordance = nil
    _.devs = {}
    
    local mt = getmetatable(o)
    local mtn = mt.__newindex

    mt.__index = function(t, k) 
        if k == "_" then return _
        elseif _[k] ~= nil then return _[k]
        else return _.affordance and _.affordance[k]
            --[[
            local c = _.affordance and _.affordance[k]
            
            -- catch shared keys, otherwise privilege affordance keys
            if k == 'new' or k == 'update' or k == 'draw' or k == 'devk' then return self[k]
            else return c or self[k] end
            ]]--
        end
    end

    mt.__newindex = function(t, k, v)
        local c = _.affordance and _.affordance[k]
    
        if c then _.affordance[k] = v
        else mtn(t, k, v) end
    end

    return o
end

_output = _obj_:new {
    is_output = true,
    redraw = nil,
    devk = nil,
    draw = function(self, devk, t)
        if (self.enabled == nil or self.p_.enabled) and self.devk == devk then
            if self.redraw then self.devs[devk].dirty = self:redraw(self.devs[devk].object, self.v, t) or self.devs[devk].dirty end
        end
    end
}

_output.new = _input.new

nest_ = _obj_:new {
    do_init = function(self)
        if self.pre_init then self:pre_init() end
        if self.init then self:init() end
        self:update()

        for i,v in ipairs(self.zsort) do if type(v) == 'table' then if v.do_init then v:do_init() end end end
    end,
    init = function(self) return self end,
    each = function(self, f) 
        for k,v in pairs(self) do 
            local r = f(k, v)
            if r then self:replace(k, r) end
        end

        return self 
    end,
    update = function(self, devk, args, mc)
        if devk == nil or args == nil then -- called w/o arguments

            local ret = nil
            for i,w in ipairs(self.zsort) do 
                if w.update then 
                    ret = w:update()
                end
            end
            
            return ret
        
        elseif self.enabled == nil or self.p_.enabled == true then
            if self.metaaffordances_enabled then 
                for i,v in ipairs(self.mc_links) do table.insert(mc, v) end
            end 

            for i,v in ipairs(self.zsort) do 
                if v.update then
                    v:update(devk, args, mc)
                end
            end
        end
    end,
    draw = function(self, devk)
        for i,v in ipairs(self.zsort) do
            if self.enabled == nil or self.p_.enabled == true then
                if v.draw then
                    v:draw(devk)
                end
            end
        end
    end,
    set = function(self, t) end,
    get = function(self) end,
    write = function(self) end,
    read = function(self) end
}

function nest_:new(o, ...)
    local clone_type

    if o ~= nil and type(o) ~= 'table' then 
        local arg = { o, ... }
        o = {}

        if type(o) == 'number' and #arg <= 2 then 
            local min = 1
            local max = 1
            
            if #arg == 1 then max = arg[1] end
            
            if #arg == 2 then 
                min = arg[1]
                max = arg[2]
            end
            
            for i = min, max do
                o[i] = nest_:new()
            end
        else
            for _,k in arg do o[k] = nest_:new() end
        end
    else
       clone_type = ...
    end

    o = _obj_.new(self, o, clone_type or nest_)
    local _ = o._ 

    _.is_nest = true
    _.enabled = true
    _.devs = {}
    _.metaaffordances_enabled = true
    _.mc_links = {}

    local mt = getmetatable(o)
    --mt.__tostring = function(t) return 'nest_' end
    
    return o
end

_affordance = nest_:new {
    value = 0,
    devk = nil,
    action = function(s, v) end,
    init = function(s) end,
    do_init = function(self)
        self:init()
    end,
    print = function(self) end,
    get = function(self, silent) 
        if not silent then
            return self:update()
        else return self.v end
    end,
    set = function(self, v, silent)
        self:replace('v', v or self.v)
        return self:get(silent)
    end
}

function _affordance:new(o)
    o = nest_.new(self, o, _obj_)
    local _ = o._    

    _.devs = {}
    _.is_affordance = true
    --_.clone_type = _obj_

    local mt = getmetatable(o)
    local mtn = mt.__newindex

    --mt.__tostring = function(t) return '_affordance' end

    mt.__newindex = function(t, k, v) 
        mtn(t, k, v)
        if type(v) == 'table' then if v.is_input or v.is_output then
            rawset(v._, 'affordance', o)
            v.devk = v.devk or o.devk
        end end
    end

    for k,v in pairs(o) do
        if type(v) == 'table' then if v.is_input or v.is_output then
            rawset(v._, 'affordance', o)
            v.devk = v.devk or o.devk
        end end
    end
 
    return o
end

_metaaffordance = _affordance:new {
    pass = function(self, sender, v, handler_args) end,
    target = nil,
    mode = 'handler' -- or 'v'
}

function _metaaffordance:new(o)
    o = _affordance.new(self, o)

    local mt = getmetatable(o)
    local mtn = mt.__newindex
    
    --mt.__tostring = function() return '_metaaffordance' end

    mt.__newindex = function(t, k, v)
        mtn(t, k, v)

        if k == 'target' then 
            vv = v

            if type(v) == 'functon' then 
                vv = v()
            end

            if type(vv) == 'table' and vv.is_nest then 
                table.insert(vv._.mc_links, o)
            end
        end
    end
    
    if o.target then
        vv = o.target

        if type(o.target) == 'functon' then 
            vv = o.target()
        end

        if type(vv) == 'table' and vv.is_nest then 
            table.insert(vv._.mc_links, o)
        end
    end

    return o
end

--local pt = include 'lib/pattern_time'

_pattern = _metaaffordance:new {
    event = _obj_:new {
        path = nil,
        package = nil
    },
    pass = function(self, sender, v, handler_args) 
        self.pattern_time.watch(self.event:new {
            path = sender:path(target),
            package = self.mode == 'v' and v or handler_args
        })
    end,
    process = function(self, event) end,
    pass = function() end,
    rec = function() end,
    loop = function() end,
    rate = function() end,
    play = function() end,
    quantize = function() end
}

function _pattern:new(o) 
    o = _obj_.new(self, o)

    --o.pattern_time = pt.new()
end

_group = _obj_:new {}

function _group:new(o)
    o = _obj_.new(self, o, _group)
    local _ = o._ 

    _.is_group = true
    _.devk = ""

    local mt = getmetatable(o)
    local mtn = mt.__newindex

    mt.__newindex = function(t, k, v)
        mtn(t, k, v)

        if type(v) == "table" then
            if v.is_affordance then
                for l,w in pairs(v) do
                    if type(w) == 'table' then
                        if w.is_input or w.is_output and not w.devk then 
                            w.devk = _.devk 
                        end
                    end
                end

                v.devk = _.devk
            elseif v.is_group or v.is_input or v.is_output then
                v.devk = _.devk
            end
        end 
    end
    return o
end

_dev = _obj_:new {
    dirty = true,
    object = nil,
    redraw = nil,
    handler = nil
}
