struct SidebarText
    get_description::Any
end

function SidebarText(; description)
    @nospecialize
    return SidebarText(description)
end

function add!(renderer::GuiRenderer, window_size::WindowSize, element::SidebarElement, ::SidebarText)
    add!(
        renderer.rectangle,
        NormalizedRect(window_size, element.x, element.y, width(element), height(element)),
        background_color(renderer.colors, false),
    )
    add!(renderer.text, window_size, element.x + 8, element.y + 4, element.description)

    return nothing
end

function update_contents!(element::SidebarElement, text::SidebarText, runner::Runner, playback::Playback)
    element.description = text.get_description(runner, playback)
    return nothing
end
