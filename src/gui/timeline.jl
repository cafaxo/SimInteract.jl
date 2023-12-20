mutable struct Timeline
    playback::Playback
    slider::SliderDefinition
end

Timeline(playback::Playback) = Timeline(playback, SliderDefinition())

value(timeline::Timeline) = cursor_position(timeline.playback.position)

function set_value!(timeline::Timeline, value::Float64)
    #if value < 1
    timeline.playback.position = move_to(timeline.playback.position, value)
    #else
    #    set_to_live!(timeline.playback)
    #end

    return nothing
end

function add!(renderer::GuiRenderer, window_size::WindowSize, timeline::Timeline)
    timeline.slider = SliderDefinition(32, window_size.height - 32 - 16, window_size.width - 64, 32, 12)
    add_slider!(renderer, window_size, timeline.slider, value(timeline), is_cursor_being_moved(timeline.playback))

    return nothing
end

function on_event!(timeline::Timeline, event::MousePressEvent)
    if should_move_slider(timeline.slider, event.cursor_position)
        set_to_cursor_being_moved!(timeline.playback)
        return true
    end

    return false
end

function on_event!(timeline::Timeline, ::MouseReleaseEvent)
    if is_cursor_being_moved(timeline.playback)
        set_to_stopped!(timeline.playback)
    end

    return false
end

function on_event!(timeline::Timeline, event::MouseMoveEvent)
    if is_cursor_being_moved(timeline.playback)
        set_value!(timeline, slider_position(timeline.slider, event.cursor_position))
    end

    return false
end
