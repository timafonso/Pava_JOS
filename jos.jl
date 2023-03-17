struct Class
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
        end

        @eval function new(c::Type{$name}; slots_values...)::$name
            instance = c(0, 0)
            for slot_pair in slots_values
                slot_name = slot_pair.first
                slot_value = slot_pair.second
                setproperty!(instance, slot_name, slot_value)
            end

            dump(slots_values...)
            return instance
        end
    end
end


@defclass(TestClass1, [], [foo, bar])

instance = new(TestClass1, foo=2)

instance


@defclass(TestClass2, [], [foo, bar, foobar])

instance = new(TestClass2, foo=2)

