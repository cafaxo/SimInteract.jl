mutable struct Visualizer
    const window_handle::GLFW.Window
    const window_state::WindowState
    const runner::Runner
    const playback::Playback
    const gui_renderer::GuiRenderer
    const sidebar::Sidebar
    const timeline::Timeline
    const state_grid_renderer::StateGridRenderer
end

function on_event!(visualizer::Visualizer, event)
    return on_event!(visualizer.timeline, event) ||
        on_event!(visualizer.sidebar, event) ||
        on_event!(visualizer.state_grid_renderer, event)
end

function update!(visualizer::Visualizer)
    # TODO: only send when actually moved
    # slider will break if only update on actual moves
    on_event!(visualizer, MouseMoveEvent(visualizer.window_state.cursor_position))

    runner = visualizer.runner
    playback = visualizer.playback
    update!(runner)

    for event in events(runner)
        @match event::RunnerEvent begin
            event_new_initial_state => reset!(playback)
        end
    end

    empty!(runner.events)

    update!(playback, number_of_states(runner))
    update_contents!(visualizer.sidebar, runner, playback)

    return nothing
end

function render(visualizer::Visualizer)
    glClearColor(0.0, 0.0, 0.0, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    window_size = visualizer.window_state.window_size
    framebuffer_size = visualizer.window_state.framebuffer_size

    render(
        visualizer.state_grid_renderer,
        window_size,
        framebuffer_size,
        visualizer.runner.outputs,
        index(visualizer.playback),
        visualizer.sidebar.viewer_parameters,
    )

    gui_renderer = visualizer.gui_renderer
    add!(gui_renderer, window_size, visualizer.sidebar)
    add!(gui_renderer, window_size, visualizer.timeline)

    render(gui_renderer)

    GLFW.SwapBuffers(visualizer.window_handle)

    return nothing
end

function setup_callbacks!(visualizer::Visualizer)
    window_handle = visualizer.window_handle
    window_state = visualizer.window_state

    GLFW.SetWindowSizeCallback(window_handle, (_, width, height) -> begin
        window_state.window_size = WindowSize(width, height)
        return nothing
    end)

    GLFW.SetCursorPosCallback(window_handle, (_, xpos, ypos) -> begin
        window_state.cursor_position = CursorPosition(xpos, ypos)
        return nothing
    end)

    GLFW.SetFramebufferSizeCallback(window_handle, (_, width, height) -> begin
        glViewport(0, 0, width, height)
        window_state.framebuffer_size = FramebufferSize(width, height)
        return nothing
    end)

    GLFW.SetWindowRefreshCallback(window_handle, _ -> begin
        render(visualizer)
        return nothing
    end)

    GLFW.SetKeyCallback(window_handle, (_, key, scancode, action, mods) -> begin
        runner = visualizer.runner
        playback = visualizer.playback

        if key == GLFW.KEY_SPACE && action == GLFW.PRESS
            toggle_playback!(playback, state(runner) == state_running)
        elseif key == GLFW.KEY_S && action == GLFW.PRESS
            request_toggle!(runner)
        elseif key == GLFW.KEY_PERIOD && action == GLFW.PRESS
            jump_forward!(playback)
        elseif key == GLFW.KEY_COMMA && action == GLFW.PRESS
            jump_backward!(playback)
        elseif (key == GLFW.KEY_PERIOD || key == GLFW.KEY_COMMA) && action == GLFW.RELEASE
            release_jump_key!(playback)
        elseif key == GLFW.KEY_N && action == GLFW.PRESS
            request_new_initial_state!(runner)
        elseif key == GLFW.KEY_R && action == GLFW.PRESS
            reset_cameras!(visualizer.state_grid_renderer)
        end

        return nothing
    end)

    GLFW.SetMouseButtonCallback(window_handle, (_, button, action, mods) -> begin
        # since this callback may be fired before the SetCursorPosCallback,
        # we have to fetch the current cursor position here
        glfw_cursor_pos = GLFW.GetCursorPos(window_handle)
        press_cursor_position = CursorPosition(glfw_cursor_pos[1], glfw_cursor_pos[2])
        visualizer.window_state.cursor_position = press_cursor_position

        if button == GLFW.MOUSE_BUTTON_LEFT
            if action == GLFW.PRESS
                on_event!(visualizer, MousePressEvent(press_cursor_position))
            elseif action == GLFW.RELEASE
                on_event!(visualizer, MouseReleaseEvent())
            end
        end

        if button == GLFW.MOUSE_BUTTON_RIGHT
            if action == GLFW.PRESS
                on_event!(visualizer, MouseRightPressEvent(press_cursor_position))
            elseif action == GLFW.RELEASE
                on_event!(visualizer, MouseRightReleaseEvent())
            end
        end

        return nothing
    end)

    GLFW.SetScrollCallback(window_handle, (_, xoffset, yoffset) -> begin
        on_event!(visualizer, MouseScrollEvent(yoffset, visualizer.window_state.cursor_position))
        return nothing
    end)

    return nothing
end

function create_visualizer_window(window_size::WindowSize)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
    GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, true)
    GLFW.WindowHint(GLFW.RESIZABLE, true)
    GLFW.WindowHint(GLFW.SAMPLES, 8)

    window_handle = GLFW.CreateWindow(window_size.width, window_size.height, "SimInteract")
    GLFW.MakeContextCurrent(window_handle)

    GLFW.SwapInterval(1)

    glEnable(GL_MULTISAMPLE)

    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glBlendEquation(GL_FUNC_ADD)

    framebuffer_width, framebuffer_height = GLFW.GetFramebufferSize(window_handle)
    framebuffer_size = FramebufferSize(framebuffer_width, framebuffer_height)

    return window_handle, WindowState(window_size, framebuffer_size, CursorPosition(0, 0))
end

"""
    launch(simulators, create_state_renderer, cameras, parameters, sidebar::Sidebar)

Launch the SimInteract window.

# Arguments
- `simulators`: List of simulators. These must implement the Simulator API (TODO: add ref).
- `create_state_renderer`: Function that creates a renderer for the simulation state, e.g. `() -> ExampleRenderer`. Must implement the Renderer API (TODO: add ref).
- `cameras`: List of cameras. These must implement the Camera API (TODO: add ref).
- `parameters`: Initial simulation parameters
- `sidebar`: A Sidebar object (TODO: add ref)
"""
function launch(simulators, create_state_renderer, cameras, parameters, sidebar::Sidebar)
    @nospecialize

    runner = Runner(simulators, parameters)
    playback = Playback()
    update_contents!(sidebar, runner, playback)

    window_handle, window_state = create_visualizer_window(WindowSize(1280, 720))

    try
        visualizer = Visualizer(
            window_handle,
            window_state,
            runner,
            playback,
            GuiRenderer(),
            sidebar,
            Timeline(playback), # TODO: is it not a bit inconsistent to take playback as arg?
            StateGridRenderer(window_state.window_size, create_state_renderer, cameras),
        )

        setup_callbacks!(visualizer)

        while !GLFW.WindowShouldClose(window_handle)
            Base.process_events()
            GLFW.PollEvents()
            update!(visualizer)
            render(visualizer)
        end

        stop!(runner)
    finally
        sleep(0.1)
        GLFW.DestroyWindow(window_handle)
    end

    return nothing
end
