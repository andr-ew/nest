local of = {
    param = function(id, offset)
        offset = offset or 0
        return {
            params:get(id) - offset,
            function(v) params:set(id, v + offset) end
        }
    end,
    controlspec = function(id)
        return params:lookup_param(id).controlspec
    end
}

return of
