const Color = SVector{4,Float32}

Base.@kwdef struct SidebarColorScheme
    default::Color
    default_hovered::Color
    unlocked::Color
    unlocked_hovered::Color
    modified::Color
    modified_hovered::Color
end

Base.@kwdef struct ColorScheme
    sidebar::SidebarColorScheme
    slider_cursor::Color
    slider_cursor_moved::Color
    slider_background::Color
    plot_cursor::Color
end

function dark_color_scheme()
    sidebar = SidebarColorScheme(;
        default = Color(54 / 255, 126 / 255, 179 / 255, 1.0),
        default_hovered = Color(77 / 255, 179 / 255, 1.0, 1.0),
        unlocked = Color(179 / 255, 60 / 255, 54 / 255, 1.0),
        unlocked_hovered = Color(1.0, 86 / 255, 77 / 255, 1.0),
        modified = Color(179 / 255, 54 / 255, 111 / 255, 1.0),
        modified_hovered = Color(1.0, 77 / 255, 159 / 255, 1.0),
    )

    return ColorScheme(;
        sidebar = sidebar,
        slider_cursor = Color(1.0, 1.0, 1.0, 0.7),
        slider_cursor_moved = Color(1.0, 1.0, 1.0, 0.9),
        slider_background = Color(1.0, 1.0, 1.0, 0.5),
        plot_cursor = Color(0.4, 0.4, 1.0, 0.5),
    )
end

slider_cursor_color(colors::ColorScheme, is_being_moved::Bool) = !is_being_moved ? colors.slider_cursor : colors.slider_cursor_moved

function background_color(colors::ColorScheme, is_hovered::Bool, is_unlocked::Bool, is_modified::Bool)
    if !is_hovered
        return if is_modified
            colors.sidebar.modified
        elseif is_unlocked
            colors.sidebar.unlocked
        else
            colors.sidebar.default
        end
    else
        return if is_modified
            colors.sidebar.modified_hovered
        elseif is_unlocked
            colors.sidebar.unlocked_hovered
        else
            colors.sidebar.default_hovered
        end
    end
end

function background_color(colors::ColorScheme, is_hovered::Bool)
    return !is_hovered ? colors.sidebar.default : colors.sidebar.default_hovered
end
