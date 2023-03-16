macro defclass(name, superclasses, slots)
    slot_names = slots.args
    quote
        struct $name
            # name::String = $name
            # superclasses::Vector{Class} = superclasses    # Type class?
            $(slot_names...)
        end
    end
end

@defclass(TestClass, [], [foo, bar])