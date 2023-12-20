struct RectangleInstance
    center::SVector{2,GLfloat}
    radius::SVector{2,GLfloat}
    color::SVector{4,GLfloat}
end

struct RectangleRenderer
    shader_program::GLuint
    vbo::StreamedBufferObject{RectangleInstance}
    vao::GLuint
end

function RectangleRenderer()
    shader_program  = setup_shader_program(shader_path("rectangle.vert"), shader_path("rectangle.frag"))
    glUseProgram(shader_program)

    vbo = StreamedBufferObject{RectangleInstance}(GL_ARRAY_BUFFER, 2^8)
    bind(vbo)

    vao = glGenVertexArray()
    glBindVertexArray(vao)

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 32, Ptr{Cvoid}(0))
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 32, Ptr{Cvoid}(8))
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, 32, Ptr{Cvoid}(16))

    glVertexAttribDivisor(0, 1)
    glVertexAttribDivisor(1, 1)
    glVertexAttribDivisor(2, 1)

    glEnableVertexAttribArray(0)
    glEnableVertexAttribArray(1)
    glEnableVertexAttribArray(2)

    return RectangleRenderer(shader_program, vbo, vao)
end

function add!(renderer::RectangleRenderer, normalized_rect::NormalizedRect, color::Color)
    push!(renderer.vbo.data, RectangleInstance(normalized_rect.center, normalized_rect.radius, color))
    return nothing
end

function render(renderer::RectangleRenderer)
    bind_and_upload(renderer.vbo)

    glUseProgram(renderer.shader_program)
    glBindVertexArray(renderer.vao)

    number_of_rectangles = length(renderer.vbo.data)
    glDrawArraysInstanced(GL_TRIANGLE_FAN, 0, 4, number_of_rectangles)

    empty!(renderer.vbo.data)

    return nothing
end

struct GlyphInstance
    center::SVector{2,GLfloat}
    radius::SVector{2,GLfloat}
    char_index::GLint
end

struct TextRenderer
    shader_program::GLuint
    font_texture::GLuint
    vbo::StreamedBufferObject{GlyphInstance}
    vao::GLuint
end

function TextRenderer()
    shader_program = setup_shader_program(shader_path("glyph.vert"), shader_path("glyph.frag"))
    glUseProgram(shader_program)

    font_texture_uniform = glGetUniformLocation(shader_program, "font_texture")
    glUniform1i(font_texture_uniform, 0)

    texture_width, texture_height = 760, 16

    texture_data = Vector{Float32}(undef, texture_width * texture_height)
    read!(font_path("font.bin"), texture_data)

    font_texture = glGenTexture()
    glBindTexture(GL_TEXTURE_2D, font_texture)
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexImage2D(
        GL_TEXTURE_2D,
        0,
        GL_RED,
        texture_width,
        texture_height,
        0,
        GL_RED,
        GL_FLOAT,
        texture_data,
    )

    vbo = StreamedBufferObject{GlyphInstance}(GL_ARRAY_BUFFER, 2^10)
    bind(vbo)

    vao = glGenVertexArray()
    glBindVertexArray(vao)

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 20, Ptr{Cvoid}(0))
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 20, Ptr{Cvoid}(8))
    glVertexAttribIPointer(2, 1, GL_INT, 20, Ptr{Cvoid}(16))

    glVertexAttribDivisor(0, 1)
    glVertexAttribDivisor(1, 1)
    glVertexAttribDivisor(2, 1)

    glEnableVertexAttribArray(0)
    glEnableVertexAttribArray(1)
    glEnableVertexAttribArray(2)

    return TextRenderer(shader_program, font_texture, vbo, vao)
end

function add!(renderer::TextRenderer, window_size::WindowSize, x::Real, y::Real, text::String)
    normalized_rect = NormalizedRect(window_size, x, y, 8, 16)

    center, radius = normalized_rect.center, normalized_rect.radius
    data = renderer.vbo.data

    for c in text
        font_char_offset = Int(c) - 32

        if font_char_offset > 126 - 32
            # out of range
            continue
        end

        push!(data, GlyphInstance(center, radius, font_char_offset))
        center = SVector(center[1] + 2*radius[1], center[2])
    end

    return nothing
end

function render(renderer::TextRenderer)
    bind_and_upload(renderer.vbo)

    glUseProgram(renderer.shader_program)
    glBindVertexArray(renderer.vao)

    glActiveTexture(GL_TEXTURE0 + 0)
    glBindTexture(GL_TEXTURE_2D, renderer.font_texture)

    number_of_glyphs = length(renderer.vbo.data)
    glDrawArraysInstanced(GL_TRIANGLE_FAN, 0, 4, number_of_glyphs)

    empty!(renderer.vbo.data)

    return nothing
end

struct PlotInstance
    center::SVector{2,GLfloat}
    radius::SVector{2,GLfloat}
    data_offset::GLint
    data_size::GLint

    function PlotInstance(center, radius, data_offset, data_size)
        @assert data_size >= 1
        return new(center, radius, data_offset, data_size)
    end
end

struct PlotRenderer
    shader_program::GLuint
    tbo::StreamedBufferObject{GLfloat}
    buffer_texture::GLuint
    vbo::StreamedBufferObject{PlotInstance}
    vao::GLuint
end

function PlotRenderer()
    shader_program = setup_shader_program(shader_path("plot.vert"), shader_path("plot.frag"))
    glUseProgram(shader_program)

    data_uniform = glGetUniformLocation(shader_program, "plot_data")
    glUniform1i(data_uniform, 0)

    tbo = StreamedBufferObject{GLfloat}(GL_TEXTURE_BUFFER, 2^15)
    bind(tbo)

    buffer_texture = glGenTexture()
    glBindTexture(GL_TEXTURE_BUFFER, buffer_texture)
    glTexBuffer(GL_TEXTURE_BUFFER, GL_R32F, tbo.name)

    vbo = StreamedBufferObject{PlotInstance}(GL_ARRAY_BUFFER, 2^9)
    bind(vbo)

    vao = glGenVertexArray()
    glBindVertexArray(vao)

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 24, Ptr{Cvoid}(0))
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 24, Ptr{Cvoid}(8))
    glVertexAttribIPointer(2, 1, GL_INT, 24, Ptr{Cvoid}(16))
    glVertexAttribIPointer(3, 1, GL_INT, 24, Ptr{Cvoid}(20))

    glVertexAttribDivisor(0, 1)
    glVertexAttribDivisor(1, 1)
    glVertexAttribDivisor(2, 1)
    glVertexAttribDivisor(3, 1)

    glEnableVertexAttribArray(0)
    glEnableVertexAttribArray(1)
    glEnableVertexAttribArray(2)
    glEnableVertexAttribArray(3)

    return PlotRenderer(
        shader_program,
        tbo,
        buffer_texture,
        vbo,
        vao,
    )
end

function add!(renderer::PlotRenderer, normalized_rect::NormalizedRect, values::AbstractVector{<:Real}, range::PlotRange)
    data = renderer.tbo.data
    old_length = length(data)
    append!(data, values)
    normalize_data!(@view(data[old_length+1:end]), range)

    push!(renderer.vbo.data, PlotInstance(normalized_rect.center, normalized_rect.radius, old_length, length(values)))

    return nothing
end

function render(renderer::PlotRenderer)
    bind_and_upload(renderer.vbo)
    bind_and_upload(renderer.tbo)

    glUseProgram(renderer.shader_program)
    glBindVertexArray(renderer.vao)

    glActiveTexture(GL_TEXTURE0 + 0)
    glBindTexture(GL_TEXTURE_BUFFER, renderer.buffer_texture)

    number_of_plots = length(renderer.vbo.data)
    glDrawArraysInstanced(GL_TRIANGLE_FAN, 0, 4, number_of_plots)

    empty!(renderer.vbo.data)
    empty!(renderer.tbo.data)

    return nothing
end

struct GuiRenderer
    rectangle::RectangleRenderer
    rectangle_front::RectangleRenderer
    text::TextRenderer
    plot::PlotRenderer
    colors::ColorScheme
end

GuiRenderer() = GuiRenderer(RectangleRenderer(), RectangleRenderer(), TextRenderer(), PlotRenderer(), dark_color_scheme())

function render(renderer::GuiRenderer)
    render(renderer.rectangle)
    render(renderer.plot)
    render(renderer.text)
    render(renderer.rectangle_front) # TODO: find a better solution

    return nothing
end
