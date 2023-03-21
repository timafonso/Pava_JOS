################################################################################################################
#                                        CLASSES                                                               #
################################################################################################################
abstract type Class end
struct ClassDef <: Class
    name::Symbol
    direct_superclasses::Vector{Class}
    direct_slots::Vector{Symbol}
end

# @defmethod print_object(class::Class, io) =
#     print(io, "<$(class_name(class_of(class))) $(class_name(class))>")

# function class_of(instance)
#   
# end

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

        #global $name = Class($name, $superclasses, $slot_names)
        global $name = $name
    end
end


################################################################################################################
#                                        METHODS                                                               #
################################################################################################################
macro defgeneric(definition)
    name = definition.args[1]
    args = definition.args[2:end]
    
    quote
        # Create a new generic function with the given name and arguments
        function $name($(args...))
        end
    end |> esc
end

macro defmethod(definition)
    name = definition.args[1].args[1]
    args = definition.args[1].args[2:end]
    body = definition.args[2]

    quote
        @eval function $name($(args...))
            $body
        end
    end
end


################################################################################################################
#                                          Testing                                                             #
################################################################################################################

@macroexpand @defclass(TestClass1, [], [foo, bar])
@defclass(TestClass1, [], [foo, bar])
c = new(TestClass1, foo=5, bar=6)
@defgeneric add(a,b)

@defmethod add(a::TestClass1, b::TestClass1) = println(c, c)
println(add(c, c))
