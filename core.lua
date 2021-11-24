nest = {
    loop = {
        device = nil,
        mode = nil,
        started = {}
    },
    handle_input = {},
    handle_redraw = {},
    device = {},
    dirty = {
        grid = true,
        screen = true,
        arc = true,
    },
    args = {},
    observers = {},
    nest.defs = {},
}

nest.constructor_error = function(name)
    print('constructor error', name)
end
nest.render_error = function(name)
    print('render error', name)
end

function nest.handle_input.device(device, handler, props, data, hargs, on_update)
    local aargs = table.pack(handler(table.unpack(hargs)))
    
    local function action()
        local v = props.action and props.action(table.unpack(aargs)) or aargs[1]

        nest.dirty[device] = true
        
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
        --TODO: pass handler, props, hargs, on_update to active observers
        
        if props.action and data.clock then
            if data.clock_id then clock.cancel(data.clock_id) end
            data.clock_id = clock.run(action)
        else
            action()
        end
    end
end

function nest.define_group = function(defgrp)
    defgrp.name = defgrp.name or ''
    defgrp.device_input = defgrp.device_input or nil
    defgrp.device_redraw = defgrp.device_redraw or nil
    defgrp.default_props = defgrp.default_props or {}
    defgrp.filter = defgrp.filter or function() end

    nest.defs[defgrp.name] = {}

    return function(def)
        def.name = def.name or ''
        def.init = def.init or function(format, data) end
        def.default_props = def.default_props or {}
        def.handlers = def.handlers or {}
        def.filter = def.filter or defgrp.filter

        nest.defs[defgrp.name][def.name] = def

        return function(state)
            if
                (not nest.loop.started[defgrp.device_input])
                and (not nest.loop.started[defgrp.device_redraw])
            then
                state = state or 0

                local default_props = def.default_props
                setmetatable(default_props, { __index = defgrp.default_props })

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
                        nest.loop.device == defgrp.device_input 
                        or nest.loop.device == defgrp.device_redraw 
                    then

                        setmetatable(props, { __index = default_props })

                        -- proxy for props & data for backwards compatability with routines/
                        local s = setmetatable({
                            p_ = setmetatable({}, {
                                __index = props,
                                __call = function(_, k, ...)
                                    if type(props[k]) == 'function' then
                                        return props[k](data, ...)
                                    else
                                        return props[k]
                                    end
                                end
                            }),
                            replace = function(s, k, v)
                                data[k] = v
                            end,
                            devs = {
                                g = setmetatable({}, {
                                    __index = function(t, k)
                                        if k=='dirty' then return nest.dirty[defgrp.device]
                                        else return rawget(t, k) end
                                    end,
                                    __newindex = function(t, k, v)
                                        if k=='dirty' then
                                            nest.dirty[defgrp.device] = v
                                        else rawset(t,k,v) end
                                    end,
                                }),
                            },
                        }, {
                            __index = data,
                            __newindex = data,
                        })

                        local st = {}
                        if props.state and props.state[1] then 
                            st = props.state
                        else
                            st = { data.value, function(v) data.value = v end }
                        end

                        local contained, fmt, size, hargs = def.filter(
                            s, nest.args[defgrp.device]
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

                            if props.state and props.state[1] then 
                                props.v = props.state[1]
                            else
                                props.v = data.value
                            end

                            if 
                                nest.loop.mode == 'input' 
                                and nest.loop.device == defgrp.device_input 
                            then
                                if contained then
                                    local shargs = { s }
                                    for i,v in ipairs(hargs) do table.insert(shargs, v) end

                                    nest.handle_input[defgrp.device](
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
                                nest.loop.mode == 'redraw'
                                and nest.loop.device == defgrp.device_redraw
                            then
                                nest.handle_redraw[defgrp.device](
                                    def.handlers.redraw[fmt], 
                                    s, 
                                    nest.device[defgrp.device], 
                                    props.v
                                )
                            elseif  
                                (
                                    defgrp.device_input 
                                    and not nest.loop.started[defgrp.device_input]
                                ) or (
                                    defgrp.device_redraw 
                                    and not nest.loop.started[defgrp.device_redraw]
                                )
                            then 
                                nest.render_error(defgrp.name..'.'..def.name..'()') 
                            end
                        end
                    else nest.constructor_error(defgrp.name..'.'..def.name..'()') end
                end
            end
        end
    end
end

return nest
