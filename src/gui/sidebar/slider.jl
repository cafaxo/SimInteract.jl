mutable struct SidebarSlider
    is_being_moved::Bool
    const value_range::SliderRange
    const get_description::Any
    const get_is_visible::Any
end

function SidebarSlider(; description, range, is_visible = returns_true)
    @nospecialize
    return SidebarSlider(false, range, description, is_visible)
end

height_expanded(element::SidebarSlider) = 8+20+32+8

function sidebar_slider_definition(element::SidebarModifier)
    return SliderDefinition(element.x + 8 + 6, element.y + 8 + 20, width(element) - 2*(8 + 6), 32, 12)
end

function on_event!(element::SidebarModifier, slider::SidebarSlider, event::MousePressEvent)
    if element.is_expanded && should_move_slider(sidebar_slider_definition(element), event.cursor_position)
        if !element.is_locked
            slider.is_being_moved = true
        end

        return true
    end

    if within_element(element, event.cursor_position)
        element.is_expanded = !element.is_expanded

        if !element.is_expanded
            slider.is_being_moved = false
        end

        return true
    end

    return false
end

function on_event!(element::SidebarModifier, slider::SidebarSlider, ::MouseReleaseEvent)
    slider.is_being_moved = false
    return false
end

function on_event!(element::SidebarModifier, slider::SidebarSlider, event::MouseMoveEvent)
    element.is_hovered = within_element(element, event.cursor_position)

    if element.is_expanded && !element.is_locked && slider.is_being_moved
        slider_pos = slider_position(sidebar_slider_definition(element), event.cursor_position)
        set_value!(element, value_from_slider_position(slider.value_range, slider_pos))
    else
        slider.is_being_moved = false
    end

    return false
end

function add!(renderer::GuiRenderer, window_size::WindowSize, element::SidebarModifier, slider::SidebarSlider)
    # FIXME: move to parent
    x, y = element.x, element.y

    add!(
        renderer.rectangle,
        NormalizedRect(window_size, x, y, width(element), height(element)),
        background_color(renderer.colors, element.is_hovered, !element.is_locked, element.is_modified),
    )
    add!(renderer.text, window_size, x + 8, y + 4, element.description)

    if !element.is_expanded
        return nothing
    end

    add_slider!(
        renderer,
        window_size,
        sidebar_slider_definition(element),
        slider_position(slider.value_range, value(element)),
        slider.is_being_moved,
    )

    return nothing
end
