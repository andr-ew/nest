local rout = include 'lib/nest/routines/txt'

local Text = {}

Text.define = nest.define_group_def{
    name = 'Text',
    device_redraw = 'screen',
    default_props = {
        aa = 0,
        font_face = 1,
        font_size = 8,
        lvl = 15,
        border = 0,
        fill = 0,
        padding = 0,
        margin = 5,
        x = 1,
        y = 1,
        size = nil,
        flow = 'x',
        align = 'left',
        line_wrap = nil,
        font_headroom = 3/8,
        font_leftroom = 1/16,
        formatter = function(s, ...) return ... end,
        scroll_window = nil, -- 6
        scroll_focus = nil, -- 3 or { 1, 6 }
        selection = nil -- 1 or { 1, 2 } or { x = 1, y = 2 }, or { { x = 1, y = 2 }, x = 3, y = 4 } }
    },
    handlers = {
        redraw = {
            point = rout.redraw,
            line = rout.redraw,
        }
    }
}

local defs = nest.defs

Text.label = Text.define{
    name = 'label',
    default_props = {},
    init = function(format, size, state, data, props) 
        data.txt = function(s) 
            return s.p_.v 
        end
    end,
    filter = function()
        --contained, fmt, size, hargs
        return nil, 'point'
    end
}

return Text
