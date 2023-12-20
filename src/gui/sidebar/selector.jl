struct SidebarSelector
    get_description::Any
    get_is_visible::Any
end

function SidebarSelector(; description, is_visible = returns_true)
    @nospecialize
    return SidebarSelector(description, is_visible)
end

function select_next!(element::SidebarModifier, current_value::T) where {T}
    number_of_states = length(instances(T))
    set_value!(element, Int(current_value) < number_of_states ? T(Int(current_value) + 1) : T(1))
    return nothing
end

function select_next!(element::SidebarModifier)
    select_next!(element, value(element)::Enum)
    return nothing
end

function on_event!(element::SidebarModifier, ::SidebarSelector, event::MousePressEvent)
    if within_element(element, event.cursor_position)
        if !element.is_locked
            select_next!(element)
        end

        return true
    end

    return false
end

function select_previous!(element::SidebarModifier, current_value::T) where {T}
    number_of_states = length(instances(T))
    set_value!(element, Int(current_value) > 1 ? T(Int(current_value) - 1) : T(number_of_states))
    return nothing
end

function select_previous!(element::SidebarModifier)
    select_previous!(element, value(element)::Enum)
    return nothing
end

function on_event!(element::SidebarModifier, ::SidebarSelector, event::MouseRightPressEvent)
    if within_element(element, event.cursor_position)
        if !element.is_locked
            select_previous!(element)
        end

        return true
    end

    return false
end

function on_event!(element::SidebarModifier, ::SidebarSelector, event::MouseMoveEvent)
    element.is_hovered = within_element(element, event.cursor_position)
    return false
end

function add!(renderer::GuiRenderer, window_size::WindowSize, element::SidebarModifier, ::SidebarSelector)
    add!(
        renderer.rectangle,
        NormalizedRect(window_size, element.x, element.y, width(element), height(element)),
        background_color(renderer.colors, element.is_hovered && !element.is_locked, !element.is_locked, element.is_modified),
    )
    add!(renderer.text, window_size, element.x + 8, element.y + 4, element.description)
    return nothing
end
