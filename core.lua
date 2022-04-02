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
    local shargs = { s }
    for i,v in pairs(hargs) do shargs[i+1] = v end

    local aargs = table.pack(handler(table.unpack(shargs)))
    
    local function action()
        if device_redraw then nest.dirty[device_redraw] = true end
        
        if props.state and props.state[2] then
            if props.action then
                print('nest: since the state[2] prop has been provided, the provided action prop will not be run. please use one prop or the other, not both')
            end

            if type(props.state[2]) == 'function' then
                props.state[2](aargs[1])
            else print('nest: the second item in the state prop table must be a function!')
        else
            local v = props.action and props.action(table.unpack(aargs)) or aargs[1]
            data.value = v
        end
        
        if(on_update) then on_update(props, data, v, shargs) end
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

nest.define_group_def = function(defgrp)
    defgrp.name = defgrp.name or ''
    defgrp.device_input = defgrp.device_input or nil
    defgrp.device_redraw = defgrp.device_redraw or nil
    defgrp.default_props = defgrp.default_props or {}
    defgrp.handlers = defgrp.handlers or {}
    defgrp.filter = defgrp.filter or function() end
    defgrp.init = defgrp.init or function(format, data) end

    nest.defs[defgrp.name] = {}

    return function(def)
        def.name = def.name or ''
        def.init = def.init or defgrp.init
        def.default_props = def.default_props or {}
        def.handlers = def.handlers or defgrp.handlers
        def.filter = def.filter or defgrp.filter
        def.device_input = def.device_input or defgrp.device_input or nil
        def.device_redraw = def.device_redraw or defgrp.device_redraw or nil

        nest.defs[defgrp.name][def.name] = def

        return function(default_props, state)
            if
                (not nest.render.started[def.device_input])
                and (not nest.render.started[def.device_redraw])
            then
                -- state = state or 0

                default_props = default_props or {}

                setmetatable(def.default_props, { __index = defgrp.default_props })
                setmetatable(default_props, { __index = def.default_props })

                if default_props.state then
                    if 
                        type(default_props.state) == 'table' and type(default_props.state[1]) == 'function' 
                    then
                    elseif type(default_props.state) == 'function' then
                    else
                        print(defgrp.name..'.'..def.name..'()'..': when passing state to a component as an argument, state[1] must be a function')
                    end
                end

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

                -- proxy for props & data for backwards compatability with routines/
                local function make_s(pprops)
                    --TODO: lvl nickname
                    return setmetatable({
                        p_ = setmetatable({}, {
                            __index = function(t, k)
                                if type(pprops[k]) == 'function' then
                                    return pprops[k](st[1], pprops, data)
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

                local function gst(pprops)
                    if 
                        pprops.state 
                        and type(pprops.state) == 'table' 
                        and pprops.state[1]
                    then 
                        return { 
                            type(pprops.state[1]) == 'function' 
                                and pprops.state[1]()
                                or pprops.state[1], 
                            pprops.state[2] or function() end 
                        }
                    elseif pprops.state then
                        return { 
                            type(pprops.state) == 'function' 
                                and pprops.state()
                                or pprops.state, 
                            function(v) end 
                        }
                    else
                        return { data.value, function(v) data.value = v end }
                    end
                end

                --(re)initialize data dynamically
                function check_init(ffmt, ssize, sst, pprops)
                    if
                        ffmt ~= data.format
                        or (
                            type(ssize)=='table' 
                            and (
                                ssize.x ~= data.size.x or ssize.y ~= data.size.y
                            ) or (
                                ssize ~= data.size
                            )
                        )
                    then
                        data.format = ffmt
                        data.size = ssize

                        def.init(ffmt, ssize, sst, data, pprops)
                    end
                end
                                
                local ds = make_s(default_props)

                -- to_input default function, which is later overwritten to a version of itself w/ updated upvalues
                local to_input = function(rargs)
                    local dst = gst(default_props)

                    local contained, fmt, size, hargs = def.filter(
                        ds, 
                        rargs
                    )
                    check_init(fmt, size, st, default_props)

                    local dsst = gst(default_props)
                    data.state = dsst

                    if contained then
                        nest.handle_input(
                            def.device_redraw,
                            def.handlers.input[fmt], 
                            default_props, 
                            data, 
                            ds,
                            hargs,
                            def.handlers.change 
                                and function(props, data, value)
                                    def.handlers.change[fmt](ds, value)
                                end
                        )
                    end
                end

                -- the second return value from the component, closes around the ever changing to_input function
                local to_this_component = function(...) to_input(...) end
                
                -- set input to the component second return value by default
                default_props.input = default_props.input or to_this_component

                return
                    function(props)
                        if 
                            nest.render.device_name == def.device_input 
                            or nest.render.device_name == def.device_redraw 
                        then
                            props = props or {}
                            setmetatable(props, { __index = default_props })
                            
                            local st = gst(props)
                            local s = make_s(props)

                            if 
                                nest.render.mode == 'input' 
                                and nest.render.device_name == def.device_input 
                            then
                                -- overwrite to_input with updated upvalues
                                to_input = function(rargs)
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
                                
                                props.input(nest.render.args)
                            elseif 
                                nest.render.mode == 'redraw'
                                and nest.render.device_name == def.device_redraw
                            then
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
                    to_this_component

            else nest.constructor_error(defgrp.name..'.'..def.name..'()') end
        end
    end
end

return nest
