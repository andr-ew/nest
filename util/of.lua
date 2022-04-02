local of = {
    param = function(id)
        return {
            params:get(id),
            function(v) params:set(id, v) end
        }
    end,
    controlspec = function(id)
        return params:lookup_param(id).controlspec
    end
}

return of
