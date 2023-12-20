struct PlotRange{F,G}
    min_func::F
    max_func::G
end

PlotRange(x, y::Real) = PlotRange(x, Returns(y))
PlotRange(x::Real, y) = PlotRange(Returns(x), y)
PlotRange(x::Real, y::Real) = PlotRange(Returns(x), Returns(y))

function normalize_data!(data::AbstractVector, range::PlotRange)
    min_value = range.min_func(data)
    max_value = range.max_func(data)

    if min_value >= max_value
        fill!(data, 0)
        return data
    end

    range_inv = inv(max_value - min_value)
    map!(x -> 2*clamp((x - min_value) * range_inv, 0, 1)-1, data, data)

    return data
end

mutable struct PlotProcessor{T,F}
    const data::Vector{T}
    const staging_area::Vector{T}
    const filter::F
    const max_size::Int
    halving_count::Int

    function PlotProcessor{T}(filter::F, max_size::Int) where {T,F}
        @assert max_size > 0 && iseven(max_size)
        return new{T,F}(T[], T[], filter, max_size, 0)
    end
end

Base.isempty(processor::PlotProcessor) = isempty(processor.data)

function Base.empty!(processor::PlotProcessor)
    empty!(processor.data)
    empty!(processor.staging_area)
    processor.halving_count = 0

    return processor
end

function Base.push!(processor::PlotProcessor, value)
    data = processor.data

    if processor.halving_count == 0
        push!(data, value)
    else
        staging_area = processor.staging_area
        push!(staging_area, value)

        if length(staging_area) == 1 << processor.halving_count
            push!(data, processor.filter(staging_area))
            empty!(staging_area)
        end
    end

    n = length(data)

    if n == processor.max_size
        for i in 1:(n ÷ 2)
            data[i] = processor.filter((data[2*i-1], data[2*i]))
        end

        resize!(data, n ÷ 2)
        processor.halving_count += 1
    end

    return processor
end
