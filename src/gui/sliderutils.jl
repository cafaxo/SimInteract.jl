abstract type AbstractSliderRange{T} end

struct SliderRange{T} <: AbstractSliderRange{T}
    min_value::T
    max_value::T
end

function slider_position(value_range::SliderRange, value)
    @assert value_range.min_value <= value <= value_range.max_value
    return (value - value_range.min_value) / (value_range.max_value - value_range.min_value)
end

function value_from_slider_position(value_range::SliderRange{Int}, slider_position::Float64)
    @assert 0 <= slider_position <= 1
    return round(Int, value_range.min_value + slider_position * (value_range.max_value - value_range.min_value))
end

function value_from_slider_position(value_range::SliderRange{<:Real}, slider_position::Float64)
    @assert 0 <= slider_position <= 1
    return min(value_range.min_value + slider_position * (value_range.max_value - value_range.min_value), value_range.max_value)
end

struct SliderRangeLog <: AbstractSliderRange{Float64}
    min_value::Float64
    max_value::Float64
end

function slider_position(value_range::SliderRangeLog, value)
    @assert value_range.min_value <= value <= value_range.max_value
    return log(value / value_range.min_value) / log(value_range.max_value / value_range.min_value)
end

function value_from_slider_position(value_range::SliderRangeLog, slider_position::Float64)
    @assert 0 <= slider_position <= 1
    return value_range.min_value^(1-slider_position) * value_range.max_value^slider_position
end

struct SliderDefinition
    x::Float64
    y::Float64
    width::Float64
    height::Float64
    cursor_width::Float64
end

SliderDefinition() = SliderDefinition(0, 0, 1, 1, 0)

function add_slider!(renderer::GuiRenderer, window_size::WindowSize, definition::SliderDefinition, value::Real, is_being_moved::Bool)
    x, y = definition.x, definition.y
    width, height = definition.width, definition.height
    cursor_width = definition.cursor_width

    add!(
        renderer.rectangle,
        NormalizedRect(window_size, x, y + height / 4, width, height / 2),
        renderer.colors.slider_background,
    )
    add!(
        renderer.rectangle,
        NormalizedRect(window_size, x - cursor_width / 2 + value * width, y, cursor_width, height),
        slider_cursor_color(renderer.colors, is_being_moved),
    )

    return nothing
end

function should_move_slider(definition::SliderDefinition, cursor_position::CursorPosition)
    cursor_width = definition.cursor_width

    return -cursor_width / 2 <= cursor_position.x - definition.x <= definition.width + cursor_width / 2 &&
        0 <= cursor_position.y - definition.y <= definition.height
end

function slider_position(definition::SliderDefinition, cursor_position::CursorPosition)
    return clamp((cursor_position.x - definition.x) / definition.width, 0.0, 1.0)
end
