
function new(name; kwargs...)
    c = name()
    for k in kwargs
        key = k.first
        setproperty!(c, key, k.second)
    end
    return c
end

macro defclass(name, superclasses, slots)
    # typeof(name) == Symbol ? nothing : throw(ArgumentError("Invalid class name type, expected Symbol."))
    # superclasses.head == Vector ? nothing : throw(ArgumentError("Invalid super class collection, expected Vector{Class} "))
    # slots.head == Vector ? nothing : throw(ArgumentError("Invalid slots collection, expected Vector{Symbol} "))

    slot_names = slots.args
    quote
        @eval mutable struct $name
            # name::String = $namec
            # superclasses::Vector{Class} = superclasses    # Type class?
            $(slot_names...)
            $name() = new()
        end

        global $name = $name
    end
end


@defclass(TestClass1, [], [foo, bar])
c = new(TestClass1, foo=5, bar=6)