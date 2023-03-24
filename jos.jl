struct Class
    name::Symbol
    direct_superclasses::Vector{Class}
    direct_slots::Vector{Symbol}
    # cpl::Vector{Class}
end

struct Instance
    metaclass::Class
    values::Vector
    Instance(metaclass) = new(metaclass, [])
end

## Instances
new(class; initargs...) =
    let instance = allocate_instance(class)
        initialize(instance, initargs)
        instance
    end

allocate_instance(class::Class) = Instance(class)

function initialize(instance::Instance, initargs)
    # TODO handle UndefKeywordError with our own exception
    for slot_name in instance.metaclass.direct_slots
        value = get(initargs, slot_name, missing)
        push!(instance.values, value)
    end
end


## Bootstraping

# Top

# Object
Object = Class(:Object, [], [])

# Class
# Class = Class(:Class, [Object], [])

## General utilites (probably not going into macros)
get_field_index(instance::Instance, slot_name::Symbol) =
    findfirst(==(slot_name), instance.metaclass.direct_slots)

## Accessors (going into macros)
function getproperty(instance::Instance, slot_name::Symbol)
    idx = get_field_index(instance, slot_name)
    instance.values[idx]
end

ComplexNumber = Class(:ComplexNumber, [Object], [:real, :img])
ist = new(ComplexNumber, img=2)

getproperty(ist, :real)


## =======
## TESTING
## =======



dump(ComplexNumber)

