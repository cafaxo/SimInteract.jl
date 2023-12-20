module SimInteract

using StaticArrays
using ModernGL
using GLFW
using Printf

shader_path(name) = joinpath(@__DIR__, "..", "assets", "shaders", name)
font_path(name) = joinpath(@__DIR__, "..", "assets", "fonts", name)

include("match.jl")
include("shaderutils.jl")
include("glutils.jl")

include("playback.jl")
include("runner.jl")

include("gui/plotutils.jl")
include("gui/colors.jl")
include("gui/renderers.jl")
include("gui/sliderutils.jl")
include("gui/timeline.jl")

include("gui/sidebar/sidebar.jl")
include("gui/sidebar/text.jl")
include("gui/sidebar/plot.jl")
include("gui/sidebar/slider.jl")
include("gui/sidebar/selector.jl")

include("gridrenderer.jl")
include("camera2d.jl")

include("visualizer.jl")

end # module SimInteract
