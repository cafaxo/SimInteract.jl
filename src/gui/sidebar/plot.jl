mutable struct SidebarPlot
    cursor_position::Float64
    data::Union{Vector{Float64},Nothing}
    const range::PlotRange
    const get_data::Any
    const get_description::Any
end

function SidebarPlot(; description, data, range::PlotRange)
    @nospecialize
    return SidebarPlot(0.0, nothing, range, data, description)
end

height_expanded(::SidebarPlot) = 100

function on_event!(element::SidebarElement, ::SidebarPlot, event::MousePressEvent)
    if within_element(element, event.cursor_position)
        element.is_expanded = !element.is_expanded
        return true
    end

    return false
end

function on_event!(element::SidebarElement, ::SidebarPlot, event::MouseMoveEvent)
    element.is_hovered = within_element(element, event.cursor_position)
    return false
end

function add!(renderer::GuiRenderer, window_size::WindowSize, element::SidebarElement, plot::SidebarPlot)
    x, y = element.x, element.y

    add!(
        renderer.rectangle,
        NormalizedRect(window_size, x, y, width(element), height(element)),
        background_color(renderer.colors, element.is_hovered),
    )
    add!(renderer.text, window_size, x + 8, y + 4, element.description)

    if !element.is_expanded || isnothing(plot.data) || isempty(plot.data)
        return nothing
    end

    plot_width = width(element) - 16
    plot_height = height(element) - 8 - 28
    add!(renderer.plot, NormalizedRect(window_size, x + 8, y + 8 + 20, plot_width, plot_height), plot.data, plot.range)

    cursor_center = x + 8 + plot_width * plot.cursor_position
    add!(
        renderer.rectangle_front,
        NormalizedRect(window_size, cursor_center - 2, y + 8 + 20, 4, plot_height),
        renderer.colors.plot_cursor,
    )

    return nothing
end

function update_contents!(element::SidebarElement, plot::SidebarPlot, runner::Runner, playback::Playback)
    state = runner.outputs[1][index(playback)].state
    analysis = runner.analysis[1]

    element.description = plot.get_description(state)
    plot.data = plot.get_data(analysis)
    plot.cursor_position = cursor_position(playback.position)
    return nothing
end
