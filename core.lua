--TODO: support multiple grids/arcs
nest = {
    render = {
        args = {},
        device = nil,
        device_name = nil,
        mode = nil,
        started = {}
    },
    -- device = {},
    dirty = {
        grid = true,
        screen = true,
        arc = true,
    },
    observers = {},
    defs = {},
}

function nest.has_input()
    return nest.render.mode == 'input'
end
function nest.is_drawing()
    return nest.render.mode == 'redraw'
end

--TODO: support arc_key
for _, dev in ipairs{ 'key', 'enc', 'screen', 'grid', 'arc' } do
    nest[dev] = {}
    nest[dev].is_constructing = function()
        return not nest.render.started[dev]
    end
    nest[dev].device = function()
        if nest[dev].has_input() or nest[dev].is_drawing() then
            return nest.render.device
        end
    end
end
for _, dev in ipairs{ 'key', 'enc', 'grid', 'arc' } do
    nest[dev].has_input = function()
        return nest.render.mode == 'input' and nest.render.device_name == dev
    end
    nest[dev].input_args = function()
        if nest[dev].has_input() then
            return table.unpack(nest.render.args)
        end
    end
end
for _, dev in ipairs{ 'screen', 'grid', 'arc' } do
    nest[dev].is_drawing = function()
        return nest.render.mode == 'redraw' and nest.render.device_name == dev
    end
    nest[dev].make_dirty = function()
        nest.dirty[dev] = true
    end
end

nest.define_connection = function(def)
    def.device_name = def.device_name or ''
    def.device = def.device or nil
    def.fps = def.fps or 30

    local redraw_flags = function()
        nest.render.args = nil
        nest.render.device_name = def.device_name
        nest.render.device = def.device
        nest.render.mode = 'redraw'
    end
    
    local input_flags = function(...)
        nest.render.args = { ... }
        nest.render.device_name = def.device_name
        nest.render.device = def.device
        nest.render.mode = 'input'
    end

    local begin_render = function(redraw_device)
        nest.render.started[def.device_name] = true
        local fps = def.fps
        local cl = clock.run(function()
            while true do
                clock.sleep(1/fps)
                if nest.dirty[def.device_name] then
                    nest.dirty[def.device_name] = false
                    redraw_device()
                end
            end
        end)
    end

    return input_flags, redraw_flags, begin_render
end

nest.constructor_error = function(name)
    print('constructor error', name)
end
nest.render_error = function(name)
    print('render error', name)
end

--TODO: this no longer needs to be a global function. refactor it into define_group_def
function nest.handle_input(device_redraw, handler, props, data, s, hargs, on_update)

    local aargs = table.pack(handler(s, table.unpack(hargs)))
    
    local function action()
        if props.state and props.state[2] then
            if props.action then
                print('nest: since the state[2] prop has been provided, the provided action prop will not be run. please use one prop or the other, not both')
            end

            local v = aargs[1]

            if type(props.state[2]) == 'function' then
                props.state[2](v)
            else 
                print('nest: the second item in the state prop table must be a function!')
            end
            
            if(on_update) then on_update(props, data, v, hargs) end
        else
            local v = props.action and props.action(table.unpack(aargs)) or aargs[1]
            data.value = v
        
            if(on_update) then on_update(props, data, v, hargs) end
        end
        
        if device_redraw then nest.dirty[device_redraw] = true end
    end

    if aargs and aargs[1] then
        if props.action and data.clock then
            if data.clock_id then clock.cancel(data.clock_id) end
            data.clock_id = clock.run(action)
        else
            action()
        end
    end
end

local devk = {
    grid = 'g',
    arc = 'a',
    screen = 'screen',
    enc = 'enc',
    key = 'key',
}

local default_props_all = {
    input_enabled = true,
    redraw_enabled = true,
}

nest.define_group_def = function(defgrp)
    defgrp.name = defgrp.name or ''
    defgrp.device_input = defgrp.device_input or nil
    defgrp.device_redraw = defgrp.device_redraw or nil
    defgrp.default_props = defgrp.default_props or {}
    defgrp.handlers = defgrp.handlers or {}
    defgrp.filter = defgrp.filter or function() end
    defgrp.init = defgrp.init or function(format, data) end

    nest.defs[defgrp.name] = {}
    
    setmetatable(defgrp.default_props, { __index = default_props_all })

    return function(def)
        def.name = def.name or ''
        def.init = def.init or defgrp.init
        def.default_props = def.default_props or {}
        def.handlers = def.handlers or defgrp.handlers
        def.filter = def.filter or defgrp.filter
        def.device_input = def.device_input or defgrp.device_input or nil
        def.device_redraw = def.device_redraw or defgrp.device_redraw or nil

        nest.defs[defgrp.name][def.name] = def


        return function(fprops)
            if
                (not nest.render.started[def.device_input])
                and (not nest.render.started[def.device_redraw])
            then
                setmetatable(def.default_props, { __index = defgrp.default_props })

                if fprops and type(fprops) ~= 'function' then
                    print('nest: the first argument to a library component constructor must be a function returning the props table')
                end

                --TODO: clock becomes prop
                local data = { 
                    clock = false,
                } 

                local handlers_blank = {
                    input = {
                        point = function(s, x, y, z) end,
                        line = function(s, x, y, z) end,
                        line_x = function(s, x, y, z) end,
                        line_y = function(s, x, y, z) end,
                        plane = function(s, x, y, z) end,
                    },
                    change = {
                        point = function(s, v) end,
                        line = function(s, x, y, z) end,
                        line_x = function(s, v) end,
                        line_y = function(s, v) end,
                        plane = function(s, v) end,
                    },
                    redraw = {
                        point = function(s, g, v) end,
                        line = function(s, x, y, z) end,
                        line_x = function(s, g, v) end,
                        line_y = function(s, g, v) end,
                        plane = function(s, g, v) end,
                    }
                }
                setmetatable(def.handlers, { __index = handlers_blank })

                -- create a proxy for props & data for backwards compatability with routines/
                local function make_s(pprops, st)
                    --TODO: lvl nickname
                    return setmetatable({
                        p_ = setmetatable({}, {
                            __index = function(t, k)
                                if type(pprops[k]) == 'function' then
                                    return pprops[k](st[1])
                                else
                                    return pprops[k]
                                end
                            end,
                            __call = function(_, k, ...)
                                if type(pprops[k]) == 'function' then
                                    return pprops[k](st[1], ...)
                                else
                                    return pprops[k]
                                end
                            end
                        }),
                        replace = function(s, k, v)
                            data[k] = v
                        end,
                        devs = def.device_redraw and {
                            [devk[def.device_redraw]] = setmetatable({}, {
                                __index = function(t, k)
                                    if k=='dirty' then 
                                        return nest.dirty[def.device_redraw]
                                    else return rawget(t, k) end
                                end,
                                __newindex = function(t, k, v)
                                    if k=='dirty' then
                                        nest.dirty[def.device_redraw] = v
                                    else rawset(t,k,v) end
                                end,
                            }),
                        },
                    }, {
                        __index = data,
                        __newindex = data,
                    })
                end

                -- get a current state & state setter depending on circumstances
                local function gst(pprops)
                    if 
                        pprops.state 
                        and type(pprops.state) == 'table' 
                        and pprops.state[1]
                    then 
                        return { 
                            pprops.state[1], 
                            pprops.state[2] or function() end 
                        }
                    elseif pprops.state then
                        return { 
                            pprops.state, 
                            function(v) end 
                        }
                    else
                        return { data.value, function(v) data.value = v end }
                    end
                end

                --(re)initialize data dynamically
                local function check_init(ffmt, ssize, sst, pprops)
                    local size_is_diffo
                    if type(ssize) == 'table' then 
                        if data.size then
                            size_is_diffo = 
                                (ssize.x ~= data.size.x) or (ssize.y ~= data.size.y)
                        else size_is_diffo = true end
                    else
                        size_is_diffo = ssize ~= data.size
                    end

                    if size_is_diffo or (ffmt ~= data.format) then
                        data.format = ffmt
                        data.size = ssize

                        def.init(data.format, data.size, sst, data, pprops)
                    end
                end

                -- process raw input args from device
                local function process_input(props, rargs)
                    if props.input_enabled then
                        local st = gst(props)
                        local s = make_s(props, st)

                        local contained, fmt, size, hargs = def.filter(
                            s, 
                            rargs
                        )

                        check_init(fmt, size, st, props)

                        local sst = gst(props)
                        props.v = sst[1]
                        data.state = sst

                        if contained then
                            nest.handle_input(
                                def.device_redraw,
                                def.handlers.input[fmt], 
                                props, 
                                data, 
                                s,
                                hargs,
                                def.handlers.change 
                                    and function(props, data, value)
                                        def.handlers.change[fmt](s, value)
                                    end
                            )
                        end
                    end
                end
               
                -- to function: second return value to send raw input into the component
                local to_input = (type(fprops) == 'function') and function(...)
                    local props = fprops() or {}
                    setmetatable(props, { __index = def.default_props })
                                
                    process_input(props, { ... })
                end
                
                -- reset: third return value to reset internal data
                local reset = (type(fprops) == 'function') and function(...)
                    local props = fprops() or {}
                    setmetatable(props, { __index = def.default_props })
                                
                    data.value = nil
                    local sst = gst(props)
                    local pprops = props

                    def.init(data.format, data.size, sst, data, pprops)
        
                    local device_redraw = def.device_redraw
                    if device_redraw then nest.dirty[device_redraw] = true end
                end

                return
                    function(props)
                        if
                            nest.render.device_name == def.device_input
                            or nest.render.device_name == def.device_redraw 
                        then  
                            if type(fprops) == 'function' and props then
                                print('nest: if a function returning props has been provided to the component constructor, there is no need to provide props to the component render function')
                            end

                            props = (type(fprops) == 'function' and fprops()) or props or {}
                            setmetatable(props, { __index = def.default_props })
                            
                            if
                                nest.render.mode == 'input' 
                                and nest.render.device_name == def.device_input 
                            then
                                if type(fprops) == 'function' then

                                    --set input to the to_ function by default
                                    props.input = props.input or to_input

                                    props.input(table.unpack(nest.render.args))
                                else
                                    process_input(props, nest.render.args)
                                end
                            elseif
                                nest.render.mode == 'redraw'
                                and nest.render.device_name == def.device_redraw
                            then
                                if props.redraw_enabled then
                                    local st = gst(props)
                                    local s = make_s(props, st)

                                    local contained, fmt, size, hargs = def.filter(
                                        s, 
                                        nest.render.args
                                    )
                                    check_init(fmt, size, st, props)

                                    local sst = gst(props)
                                    props.v = sst[1]
                                    data.state = sst

                                    def.handlers.redraw[fmt](
                                        s, 
                                        props.v,
                                        nest.render.device
                                    )
                                end
                            elseif  
                                (
                                    def.device_input 
                                    and not nest.render.started[def.device_input]
                                ) or (
                                    def.device_redraw 
                                    and not nest.render.started[def.device_redraw]
                                )
                            then 
                                nest.render_error(defgrp.name..'.'..def.name..'()')
                            end
                        end
                    end,
                    to_input,
                    reset

            else nest.constructor_error(defgrp.name..'.'..def.name..'()') end
        end
    end
end

return nest
