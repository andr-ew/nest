to = {}

to.pattern = function(mpat, id, Comp, fprops)
    local wrapped
    local _comp, to_comp

    _comp, to_comp = Comp(function() 
        local props = fprops()

        if type(props.state) == 'table' and props.state[2] then
            local state2 = props.state[2]
            wrapped = wrapped or mpat:wrap(id, state2)

            props.state[2] = wrapped
        elseif props.action then
            wrapped = wrapped or mpat:wrap(id, function(...) to_comp(...) end)

            props.input = wrapped
        end

        return props
    end)

    return _comp
end

return to
