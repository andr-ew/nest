local function PatternRecorder()
    local _tog = Grid.toggle()

    return function(props)
        local off = 0
        local dim = (props.varibright == false) and 0 or 4
        local med = (props.varibright == false) and 15 or 4
        local hi = 15

        props.lvl = {
            off, ------------------ 0 empty
            function(s, d) ------ 1 empty, recording, no playback
                while true do
                    d(med)
                    clock.sleep(0.25)
                    d(off)
                    clock.sleep(0.25)
                end
            end,
            dim, ------------------ 2 filled, paused
            hi, ----------------- 3 filled, playback
            function(s, d) ------ 4 filled, recording, playback
                while true do
                    d(hi)
                    clock.sleep(0.2)
                    d(off)
                    clock.sleep(0.2)
                end
            end,
        }

        props.edge = 'falling'

        props.include = function(v, x, y) --limit range based on pattern clear state
            local p
            if x and y then p = props.pattern[x][y]
            elseif x then p = props.pattern[x]
            else p = props.pattern end
            
            --print(props.pattern, props.pattern[1], x, y)

            if p.count > 0 then
                --if p.overdub then return { 2, 4 }
                --else return { 2, 3 } end
                return { 2, 3 }
            else
                return { 0, 1 }
            end
        end

        local action = props.action

        props.action = function(value, time, delta, add, rem, list)
            -- assign variables, setter function based on affordance dimentions
            local set, p, v, t, d
            local switch = props.count == 1

            if type(value) == 'table' then
                local i = add or rem
                if i then
                    if type(value)[1] == 'table' then
                        p = props.pattern[i.x][i.y]
                        t = time[i.x][i.y]
                        d = delta[i.x][i.y]
                        v = value[i.x][i.y]
                        set = function(val)
                            ----- hacks
                            if val == 0 then
                                for j,w in ipairs(list) do
                                    if w.x == i.x and w.y == i.y then 
                                        rem = table.remove(list, j)
                                    end
                                end
                            else
                                if not tab.contains(list, i) then table.insert(list, i) end
                                if switch and #list > 1 then table.remove(list, 1) end
                            end
                            value[i.x][i.y] = val
                            return value
                        end
                    else
                        p = props.pattern[i]
                        t = time[i]
                        d = delta[i]
                        v = value[i]
                        set = function(val)
                            ----- hacks
                            if val == 0 then
                                local k = tab.key(list, i)
                                if k then
                                    table.remove(list, k)
                                end
                            else
                                if not tab.contains(list, i) then table.insert(list, i) end
                                if switch and #list > 1 then table.remove(list, 1) end
                            end

                            value[i] = val
                            return value
                        end
                    end
                end
            else 
                p = props.pattern
                t = time
                d = delta
                v = value
                set = function(val) return val end
            end

            local function stop_all()
                if switch then
                    if type(value) == 'table' then
                        if type(value)[1] == 'table' then
                            for i,x in ipairs(props.pattern) do
                                for j,y in ipairs(x) do
                                    if y.rec == 1 then y:rec_stop() end
                                    y:stop()
                                end
                            end
                        else
                            for j,w in ipairs(props.pattern) do
                                if w.rec == 1 then w:rec_stop() end
                                w:stop()
                            end
                        end
                    else
                        local w = props.pattern
                        if w.rec == 1 then w:rec_stop() end
                        w:stop()
                    end

                    if props.stop then props.stop() end
                end
            end

            if p then
                if t > 0.5 then -- hold to clear
                    if props.stop then props.stop() end
                    p:clear()
                    print('pat clear')

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
                                    if props.stop then props.stop() end
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

            if action then action(value, time, delta, add, rem, list) end
        end

        _tog(props)
    end
end

return PatternRecorder
