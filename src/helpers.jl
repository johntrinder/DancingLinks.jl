
const units_dict = Dict{Int, Symbol}(1=>:ns, 2=>:μs, 3=>:ms, 4=>:sec, 5=>:min, 6=>:hr, 7=>:day)
const units_dict2 = Dict{Symbol, Int}(:ns=>1, :mus=>2, :μs=>2, :ms=>3, :s=>4, :sec=>4, :m=>5, :h=>6, :d=>7)

"""
        convert_nanoseconds(nanosecs::UInt64; # from time_ns() function
                        [ncols]::Integer = 0, # < 0 = discard leading zero values; print most significant column first (cf examples below)
                        [units]::Union{Nothing, Symbol}=nothing,  # != nothing : eg. :ms; last columns is in these units
                                                                # otherwise last column is arbitrary units
                                                                # units = :d, :h, :m, {:s|:sec}, :ms, {:mus|μs}, :ns
                        [omitunits]::Bool=false # whether or not to print the units string
                        )::String
This function is to be used in conjunction with, for eg, `time_ns()`
# Examples
    t = 1.500600e9 # nanoseconds
    convert_nanoseconds(t, ncols = 0, units=nothing)   -> "01:500:600μs"
    convert_nanoseconds(t, ncols = +1, units=nothing)  -> "1500600μs"
    convert_nanoseconds(t, ncols = -1, units=nothing)  -> "2s"
    convert_nanoseconds(t, ncols = +2, units=nothing)  -> "1500:600μs"
    convert_nanoseconds(t, ncols = -2, units=nothing)  -> "01:501ms"
    convert_nanoseconds(t, ncols = +3, units=:ms)      -> "00:01:501ms"
    convert_nanoseconds(t, ncols = -3, units=:ms)      -> "01:501ms"
"""
function convert_nanoseconds(nanosecs::Real; 
                        ncols::Integer=0, units::Union{Nothing, Symbol}=nothing, omitunits::Bool=false
                        )::String
    units !== nothing && !haskey(units_dict2, units) && error("Arg `units`=$(units) is unrecognised.")
    nanosecs % 1 != 0 && error("Arg `nanosecs` % 1 must = 0.")
    ns::UInt64 = nanosecs
    ncols_ = abs(ncols)
    # prepare `times` vector:
    limits = [ 24, 60, 60, 1000, 1000, 1000 ]
    rlimits = reverse(limits)
    times = Vector{UInt64}()
    for el in rlimits
        d,r = divrem(ns, el)
        push!(times, r)
        ns = d
    end
    push!(times, ns) # now in order of: ns,mus,ms,s,m,h,d
    # println(reverse(times))
    allzero::Bool = sum(times) == 0
    start_ix = end_ix = nothing

    # compute start_ix:
    if units === nothing
        if allzero 
            start_ix = end_ix = 1
        else
            ncols >= 0 && (start_ix = findfirst(el->el>0, times))
            ncols < 0 && (end_ix = findlast(el->el>0, times))
        end
    else
        start_ix = units_dict2[units]
    end

    # compute end_ix|start_ix:
    if ncols == 0
        if allzero
            ncols_ = 1
            end_ix = start_ix
        else
            end_ix = findlast(el->el>0, times)
            ncols_ = end_ix - start_ix + 1
        end
    else
        (ncols > 0 || units !== nothing) && (end_ix = min(ncols_ + start_ix - 1, length(times)))
        if !allzero
            ncols < 0 && units === nothing && (start_ix = max(end_ix - ncols_ + 1, 1))
            ncols_ = end_ix - start_ix + 1
        elseif ncols < 0
            end_ix = start_ix
            ncols_ = 1
        else
            end_ix = start_ix + ncols_ - 1
        end
    end

    # recompute end_ix to most significant column:
    if !allzero && ncols < 0
        e = findlast(el->el>0, times)
        e < end_ix && (end_ix = e)
        ncols_ = end_ix - start_ix + 1
    end

    # propogate over half-limits:
    for ix in 1:start_ix - 1
        lim = rlimits[ix]/2
        times[ix] >= lim && (times[ix + 1] += 1)
    end

    #propogate over carries:
    for ix in start_ix:length(times) - 1
        lim = rlimits[ix]
        if times[ix] == lim
            times[ix + 1] += 1
            times[ix] = 0
            ix >= end_ix && ncols == 0 && (ncols_ += 1; end_ix += 1)
        end
    end

    #propogate backwards to accumulate for end_ix:
    accum = 0
    for ix in length(times):-1:end_ix + 1
        accum = times[ix] + rlimits[ix - 1] * accum
    end
    end_ix < length(times) && (times[end_ix] += accum * rlimits[end_ix])

    end_ix < start_ix && (end_ix = start_ix; ncols_ = 1)
    
    # results to string:
    s = omitunits ? "" : ' ' * string(units_dict[start_ix])
    for ix in start_ix:end_ix
        s2 = string(times[ix])
        colon = ix == start_ix ? "" : ':'
        lim = ix > length(rlimits) ? -1 : rlimits[ix]
        n = lim == 1000 ? 3 : 2
        (ncols_ == 1 || lim == -1 || ix == end_ix && lim == 1000) && (n = 1)
        s = lpad(s2, n, '0') * colon * s
    end
    return s
end
 
"""
vector_sans_type(vec::AbstractVector)::String
# Example        
foo() = nothing
l = [[:abc, nothing, foo], [:def, 'V', 2.0], [:ghi, "abc"]] # foo is a Function
println(vector_sans_type(l))
"""
function vector_sans_type(vec::AbstractVector)::String
    io = IOBuffer()

    function recurse(v::AbstractVector)
    print(io, "[")
    for (i, elt) in enumerate(v)
        i > 1 && print(io, ", ")
        if elt isa AbstractVector
            recurse(elt)
        else
            show(io, elt)
        end
    end
    print(io, "]")
    end
    recurse(vec)

    return String(take!(io))
end
