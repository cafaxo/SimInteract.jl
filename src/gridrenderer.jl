mutable struct StateGridElement{R,C}
    const renderer::R
    const camera::C
    rect::CursorRect
end

mutable struct StateGridRenderer{R,C}
    const instances::Vector{StateGridElement{R,C}}
    selected_instance::Int
end

function update_rects!(state_grid_renderer::StateGridRenderer, window_size::WindowSize)
    number_of_instances = length(state_grid_renderer.instances)

    # FIXME: create a good, general splitting strategy
    square_root = round(Int, sqrt(number_of_instances))
    @assert number_of_instances == square_root^2

    sidebar_width = 256 + 8

    rect = CursorRect(
        sidebar_width,
        0,
        window_size.width - sidebar_width,
        window_size.height,
    )

    xgrid = range(start=rect.x, stop=rect.x + rect.width, length=square_root+1)
    ygrid = range(start=rect.y, stop=rect.y + rect.height, length=square_root+1)

    for i in 1:square_root, j in 1:square_root
        state_grid_renderer.instances[((i-1)*square_root) + j].rect = CursorRect(
            xgrid[i],
            ygrid[j],
            xgrid[i+1] - xgrid[i],
            ygrid[j+1] - ygrid[j],
        )
    end

    return nothing
end

function StateGridRenderer(
        window_size::WindowSize,
        create_state_renderer,
        cameras,
    )
    state_grid_renderer = StateGridRenderer(
        [StateGridElement(create_state_renderer(), camera, CursorRect(0, 0, 0, 0)) for camera in cameras],
        1,
    )

    update_rects!(state_grid_renderer, window_size)
    return state_grid_renderer
end

function reset_cameras!(state_grid_renderer::StateGridRenderer)
    for (; camera) in state_grid_renderer.instances
        reset!(camera)
    end

    return nothing
end

function render(
        state_grid_renderer::StateGridRenderer,
        window_size::WindowSize,
        framebuffer_size::FramebufferSize,
        runner_outputs,
        state_index::Int,
        viewer_parameters::Dict,
    )
    update_rects!(state_grid_renderer, window_size)

    @assert length(runner_outputs) == length(state_grid_renderer.instances)

    for (i, instance) in enumerate(state_grid_renderer.instances)
        render(
            instance.renderer,
            window_size,
            framebuffer_size,
            instance.rect,
            instance.camera,
            runner_outputs[i][state_index],
            viewer_parameters,
        )
    end

    return nothing
end

function on_event!(state_grid_renderer::StateGridRenderer, event)
    return any(instance -> on_event!(instance.camera, event), state_grid_renderer.instances)
end

function on_event!(state_grid_renderer::StateGridRenderer, event::Union{MousePressEvent,MouseRightPressEvent})
    for (; camera, rect) in state_grid_renderer.instances
        if within(rect, event.cursor_position) && on_event!(camera, event)
            return true
        end
    end

    return false
end

function on_event!(state_grid_renderer::StateGridRenderer, event::MouseScrollEvent)
    for (; camera, rect) in state_grid_renderer.instances
        if within(rect, event.cursor_position) && on_scroll_event!(camera, event, center(rect))
            return true
        end
    end

    return false
end
