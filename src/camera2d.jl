mutable struct Camera2D
    offset::SVector{2,Float64}
    is_mouse_pressed::Bool
    offset_on_press::SVector{2,Float64}
    cursor_position_on_press::CursorPosition
    const initial_scale::Float64
    scale::Float64
end

function Camera2D(scale::Float64)
    return Camera2D(
        SVector(0, 0),
        false,
        SVector(0, 0),
        CursorPosition(0, 0),
        scale,
        scale,
    )
end

function reset!(camera::Camera2D)
    camera.offset = SVector(0, 0)
    camera.is_mouse_pressed = false
    camera.scale = camera.initial_scale

    return camera
end

function on_event!(camera::Camera2D, event::MousePressEvent)
    camera.is_mouse_pressed = true
    camera.offset_on_press = camera.offset
    camera.cursor_position_on_press = event.cursor_position
    return true
end

function on_event!(camera::Camera2D, event::MouseReleaseEvent)
    camera.is_mouse_pressed = false
    return false
end

function on_event!(camera::Camera2D, event::MouseMoveEvent)
    if camera.is_mouse_pressed
        current_movement = SVector(
            event.cursor_position.x - camera.cursor_position_on_press.x,
            event.cursor_position.y - camera.cursor_position_on_press.y,
        )

        camera.offset = camera.offset_on_press + current_movement
    end

    return false
end

function on_scroll_event!(camera::Camera2D, event::MouseScrollEvent, center::SVector{2,Float64})
    scale = exp(0.1 * event.yoffset)

    camera.offset -= event.cursor_position - center
    camera.offset_on_press -= camera.cursor_position_on_press - center

    camera.offset *= scale
    camera.offset_on_press *= scale
    camera.scale *= scale

    camera.offset += event.cursor_position - center
    camera.offset_on_press += camera.cursor_position_on_press - center

    return false
end
