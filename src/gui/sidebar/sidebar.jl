function returns_true(x)
    @nospecialize
    return true
end

function within_element(element, cursor_position::CursorPosition)
    return 0 <= cursor_position.x - element.x <= width(element) &&
           0 <= cursor_position.y - element.y <= height(element)
end

mutable struct SidebarElement
    x::Int
    y::Int
    is_expanded::Bool
    is_hovered::Bool
    description::String # FIXME: change to IOBuffer
    const content::Any
end

function SidebarElement(content)
    @nospecialize
    return SidebarElement(0, 0, false, false, "", content)
end

width(::SidebarElement) = 256
height(element::SidebarElement) = !element.is_expanded ? 24 : height_expanded(element.content)::Int

function on_event!(element::SidebarElement, content::Any, event)
    return false
end

function on_event!(element::SidebarElement, event)
    return on_event!(element, element.content, event)::Bool
end

function add!(renderer::GuiRenderer, window_size::WindowSize, element::SidebarElement)
    add!(renderer, window_size, element, element.content)
    return nothing
end

mutable struct SidebarModifier
    x::Int
    y::Int
    is_visible::Bool
    is_expanded::Bool
    is_hovered::Bool
    is_locked::Bool
    is_modified::Bool
    description::String # FIXME: change to IOBuffer
    const identifier::Symbol
    const parameters::Dict{Symbol,Any}
    const content::Any
end

function SidebarModifier(identifier::Symbol, parameters::Dict{Symbol,Any}, content)
    @nospecialize
    return SidebarModifier(
        0, 0, true, false, false, false, false, "", identifier, parameters, content
    )
end

value(modifier::SidebarModifier) = modifier.parameters[modifier.identifier]

function set_value!(modifier::SidebarModifier, @nospecialize(value))
    modifier.parameters[modifier.identifier] = value
    return nothing
end

width(::SidebarModifier) = 256
height(element::SidebarModifier) = !element.is_expanded ? 24 : height_expanded(element.content)::Int

function on_event!(element::SidebarModifier, content::Any, event)
    return false
end

function on_event!(element::SidebarModifier, event)
    return on_event!(element, element.content, event)::Bool
end

function add!(renderer::GuiRenderer, window_size::WindowSize, element::SidebarModifier)
    add!(renderer, window_size, element, element.content)
    return nothing
end

function default_simulation_info()
    return Any[
        SidebarText(;
            description = (runner, playback) -> @sprintf("State %i / %i", index(playback), number_of_states(runner))
        ),
        SidebarText(;
            description = (runner, playback) -> describe(state(playback))
        ),
        SidebarText(;
            description = (runner, playback) -> describe(state(runner))
        ),
    ]
end

to_dict(x) = Dict{Symbol,Any}(key => getfield(x, key) for key in propertynames(x))

# T(; dict...) is awfully slow. much faster alternative:
@generated function from_dict(::Type{T}, dict::Dict{Symbol,Any}) where {T}
    expr = Expr(:call)
    args = expr.args

    push!(args, T)

    for field in fieldnames(T)
        push!(args, Expr(:ref, :dict, QuoteNode(field)))
    end

    return expr
end

# viewer_* stuff is not coupled to the runner; just for changing visualizer settings

mutable struct Sidebar
    const elements::Vector{SidebarElement}
    const viewer_modifiers::Vector{SidebarModifier}
    viewer_parameters::Dict{Symbol,Any}
    const modifiers::Vector{SidebarModifier}
    parameters::Dict{Symbol,Any}
end

"""
    Sidebar(; [simulation_info, state_info, viewer_modifiers, modifiers, parameters])

Specify which information will be displayed during the simulation.
A list of GUI widgets that control simulation parameters can also be supplied.
All arguments are optional.

# Arguments
- `simulation_info`: List of GUI widgets that display basic information about the application state (e.g. whether the simulation is currently running)
- `state_info`: List of GUI widgets that display information about the simulation state.
- `viewer_modifiers`:
- `viewer_parameters`:
- `modifiers`:
- `parameters`:
"""
function Sidebar(;
        simulation_info::Vector{Any} = default_simulation_info(),
        state_info::Vector{Any} = Any[],
        viewer_modifiers::Vector{Pair{Symbol,Any}} = Pair{Symbol,Any}[],
        viewer_parameters::Dict{Symbol,Any} = Dict{Symbol,Any}(),
        modifiers::Vector{Pair{Symbol,Any}} = Pair{Symbol,Any}[],
        parameters = nothing,
    )

    parameters = to_dict(parameters)
    elements = [SidebarElement(content) for content in simulation_info]
    append!(elements, [SidebarElement(content) for content in state_info])

    return Sidebar(
        elements,
        [SidebarModifier(identifier, viewer_parameters, content) for (identifier, content) in viewer_modifiers],
        viewer_parameters,
        [SidebarModifier(identifier, parameters, content) for (identifier, content) in modifiers],
        parameters,
    )
end

function on_event!(sidebar::Sidebar, event)
    for element in sidebar.elements
        if on_event!(element, event)
            return true
        end
    end

    for element in sidebar.viewer_modifiers
        if element.is_visible && on_event!(element, event)
            return true
        end
    end

    for element in sidebar.modifiers
        if element.is_visible && on_event!(element, event)
            return true
        end
    end

    return false
end

function update_layout!(sidebar::Sidebar)
    pos_x = 2
    pos_y = 2

    for element in sidebar.elements
        element.x = pos_x
        element.y = pos_y
        pos_y += height(element) + 2
    end

    for element in sidebar.viewer_modifiers
        if !element.is_visible
            continue
        end

        element.x = pos_x
        element.y = pos_y
        pos_y += height(element) + 2
    end

    for element in sidebar.modifiers
        if !element.is_visible
            continue
        end

        element.x = pos_x
        element.y = pos_y
        pos_y += height(element) + 2
    end

    return nothing
end

function add!(renderer::GuiRenderer, window_size::WindowSize, sidebar::Sidebar)
    for element in sidebar.elements
        add!(renderer, window_size, element)
    end

    for element in sidebar.viewer_modifiers
        if !element.is_visible
            continue
        end

        add!(renderer, window_size, element)
    end

    for element in sidebar.modifiers
        if !element.is_visible
            continue
        end

        add!(renderer, window_size, element)
    end

    return nothing
end

function update_modifier!(element::SidebarModifier, show_parameters, current_parameters, is_locked::Bool)
    set_value!(element, getfield(show_parameters, element.identifier))
    content = element.content
    current_value = getfield(current_parameters, element.identifier)
    element.is_locked = is_locked
    element.is_modified = value(element) != current_value
    element.description = content.get_description(value(element))
    element.is_visible = content.get_is_visible(element.parameters)

    return nothing
end

function update_modifiers!(sidebar::Sidebar, runner::Runner, playback::Playback)
    current_index = index(playback)
    # FIXME: current is a bad name. simulated_params?
    current_parameters = runner.outputs[1][current_index].parameters

    modifiers_were_locked = any(element -> element.is_locked, sidebar.modifiers)
    modifiers_locked = cursor_position(playback.position) != 1

    if !modifiers_locked && !modifiers_were_locked
        set_parameters!(runner, from_dict(typeof(runner.parameters), sidebar.parameters))
    end

    show_parameters = cursor_position(playback.position) == 1 ? parameters(runner) : current_parameters

    for element in sidebar.modifiers
        update_modifier!(element, show_parameters, current_parameters, modifiers_locked)
    end

    return nothing
end

function update_contents!(sidebar::Sidebar, runner::Runner, playback::Playback)
    for element in sidebar.elements
        update_contents!(element, element.content, runner, playback)
    end

    # FIXME: HACKY HACK
    for modifier in sidebar.viewer_modifiers
        content = modifier.content
        modifier.description = content.get_description(value(modifier))
        modifier.is_visible = content.get_is_visible(modifier.parameters)
    end

    update_modifiers!(sidebar, runner, playback)
    update_layout!(sidebar)

    return nothing
end
