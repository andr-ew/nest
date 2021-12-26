local from = {
    param = function(id)
        return {
            params:get(id),
            function(v) params:set(id, v) end
        }
    end,
    -- tbh: it might make more sense to PR a little getter for this upstream
    -- params:get_controlspec('ctl')
    controlspec = function(id)
        return params:lookup_param(id).controlspec
    end
}

return from
