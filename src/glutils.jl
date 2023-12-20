function glGenOne(glGenFn)
    name = Ref{GLuint}()
    glGenFn(1, name)
    return name[]
end

glGenBuffer() = glGenOne(glGenBuffers)
glGenVertexArray() = glGenOne(glGenVertexArrays)
glGenTexture() = glGenOne(glGenTextures)

struct StreamedBufferObject{T}
    target::GLenum
    name::GLuint
    capacity::Int
    data::Vector{T}

    function StreamedBufferObject{T}(target::GLenum, capacity::Int) where {T}
        @assert isbitstype(T)
        data = T[]
        sizehint!(data, capacity)

        return new{T}(target, glGenBuffer(), capacity, data)
    end
end

function bind(buffer_object::StreamedBufferObject)
    glBindBuffer(buffer_object.target, buffer_object.name)
    return nothing
end

function bind_and_upload(buffer_object::StreamedBufferObject{T}) where {T}
    @assert length(buffer_object.data) <= buffer_object.capacity

    target = buffer_object.target

    glBindBuffer(target, buffer_object.name)
    glBufferData(target, sizeof(T) * buffer_object.capacity, C_NULL, GL_STREAM_DRAW)
    glBufferSubData(target, 0, sizeof(buffer_object.data), buffer_object.data)

    return nothing
end

struct WindowSize <: FieldVector{2,Int}
    width::Int
    height::Int
end

struct FramebufferSize <: FieldVector{2,Int}
    width::Int
    height::Int
end

# TODO: better terminology. this is also used for glScissor...
struct CursorRect
    x::Float64
    y::Float64
    width::Float64
    height::Float64
end

center(rect::CursorRect) = SVector{2,Float64}(rect.x + rect.width / 2, rect.y + rect.height / 2)

function Base.intersect(r::CursorRect, s::CursorRect)
    return CursorRect(
        max(r.x, s.x),
        max(r.y, s.y),
        min(r.x + r.width, s.x + s.width) - max(r.x, s.x),
        min(r.y + r.height, s.y + s.height) - max(r.y, s.y),
    )
end

struct CursorPosition <: FieldVector{2,Float64}
    x::Float64
    y::Float64
end

function within(rect::CursorRect, cursor_position::CursorPosition)
    return rect.x <= cursor_position.x < rect.x + rect.width &&
        rect.y <= cursor_position.y < rect.y + rect.height
end

struct FramebufferRect
    x::Int
    y::Int
    width::Int
    height::Int
end

function FramebufferRect(cursor_rect::CursorRect, window_size::WindowSize, framebuffer_size::FramebufferSize)
    @assert window_size.width > 0 && window_size.height > 0

    scale_factors = framebuffer_size ./ window_size

    return FramebufferRect(
        round(Int, scale_factors[1] * cursor_rect.x),
        round(Int, framebuffer_size.height - scale_factors[2] * (cursor_rect.y + cursor_rect.height)),
        round(Int, scale_factors[1] * cursor_rect.width),
        round(Int, scale_factors[2] * cursor_rect.height),
    )
end

# TODO: normalized how? properly name this.
struct NormalizedRect
    center::SVector{2,GLfloat}
    radius::SVector{2,GLfloat}
end

# TODO: x, y, width, height are a CursorRect. make explicit?
function NormalizedRect(window_size::WindowSize, x::Real, y::Real, width::Real, height::Real)
    center = SVector{2,GLfloat}(-1 + (2*x + width) / window_size.width, 1 - (2*y + height) / window_size.height)
    radius = SVector{2,GLfloat}(width / window_size.width, height / window_size.height)

    return NormalizedRect(center, radius)
end

mutable struct WindowState
    window_size::WindowSize
    framebuffer_size::FramebufferSize
    cursor_position::CursorPosition
end

struct MousePressEvent
    cursor_position::CursorPosition
end

struct MouseReleaseEvent end

struct MouseRightPressEvent
    cursor_position::CursorPosition
end

struct MouseRightReleaseEvent end

struct MouseMoveEvent
    cursor_position::CursorPosition
end

struct MouseScrollEvent
    yoffset::Float64
    cursor_position::CursorPosition
end

on_event!(::Any, ::Any) = false
