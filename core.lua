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

function nest.handle_input(device_redraw, handler, props, data, hargs, on_update)
    --TODO: pass handler, props, hargs, on_update to active observers
        
    local aargs = table.pack(handler(table.unpack(hargs)))
    
    local function action()
        local v = props.action and props.action(table.unpack(aargs)) or aargs[1]

        if device_redraw then nest.dirty[device_redraw] = true end
        
        if(props.state and props.state[2]) then
            --TODO: throw helpful error if state[2] is not a function
            aargs[1] = v
            props.state[2](table.unpack(aargs))
        else
            data.value = v
        end
        
        if(on_update) then on_update(props, data, v, hargs) end
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

        return function(state)
            if
                (not nest.render.started[def.device_input])
                and (not nest.render.started[def.device_redraw])
            then
                -- state = state or 0

                setmetatable(def.default_props, { __index = defgrp.default_props })

                local data = { 
                    clock = true,
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

                return function(props)
                    if 
                        nest.render.device_name == def.device_input 
                        or nest.render.device_name == def.device_redraw 
                    then

                        setmetatable(props, { __index = def.default_props })

                        local function gst()
                            if 
                                props.state 
                                and type(props.state) == 'table' 
                                and props.state[1]
                            then 
                                return { props.state[1], props.state[2] or function() end }
                            elseif props.state then
                                return { props.state, function(v) end }
                            else
                                return { data.value, function(v) data.value = v end }
                            end
                        end
                        
                        local st = gst()

                        -- proxy for props & data for backwards compatability with routines/
                        
                        --TODO: lvl nickname
                        local s = setmetatable({
                            p_ = setmetatable({}, {
                                __index = function(t, k)
                                    if type(props[k]) == 'function' then
                                        return props[k](st[1], props, data)
                                    else
                                        return props[k]
                                    end
                                end,
                                __call = function(_, k, ...)
                                    if type(props[k]) == 'function' then
                                        return props[k](st[1], ...)
                                    else
                                        return props[k]
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

                        local contained, fmt, size, hargs = def.filter(
                            s, 
                            nest.render.args
                            -- [
                            --     nest.render.mode == 'input' 
                            --     and def.device_input 
                            --     or def.device_redraw
                            -- ]
                        )

                        if fmt then
                            --(re)initialize data dynamically
                            if
                                fmt ~= data.format
                                or (
                                    type(size)=='table' 
                                    and (
                                        size.x ~= data.size.x or size.y ~= data.size.y
                                    ) or (
                                        size ~= data.size
                                    )
                                )
                            then
                                data.format = fmt
                                data.size = size

                                def.init(fmt, size, st, data, props)
                            end

                            local sst = gst()
                            props.v = sst[1]
                            data.state = sst

                            if 
                                nest.render.mode == 'input' 
                                and nest.render.device_name == def.device_input 
                            then
                                if contained then
                                    local shargs = { s }
                                    for i,v in pairs(hargs) do shargs[i+1] = v end

                                    nest.handle_input(
                                        def.device_redraw,
                                        def.handlers.input[fmt], 
                                        props, 
                                        data, 
                                        shargs,
                                        def.handlers.change and function(props, data, value)
                                            def.handlers.change[fmt](s, value)
                                        end
                                    )
                                end
                            elseif 
                                nest.render.mode == 'redraw'
                                and nest.render.device_name == def.device_redraw
                            then
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
                    end
                end
            else nest.constructor_error(defgrp.name..'.'..def.name..'()') end
        end
    end
end

return nest
