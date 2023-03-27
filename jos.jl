mutable struct Instance
    metaclass::Instance
    slots::Vector{}  # In classes index 1 is superclasses and index 2 is direct slots
    Instance() = new()
    Instance(metaclass) = new(metaclass, [])
end

####################################################################
#                         BASE CLASSES                             #
####################################################################

#------------------------- class Class -----------------------------
Class = Instance()
Class.metaclass = Class
Class.slots = []

Object = Instance()
Object.metaclass = Class


push!(Class.slots, [Object])
push!(Class.slots, [:direct_superclasses, :direct_slots])
####################################################################

####################################################################
#                            UTILS                                 #
####################################################################
function get_direct_slots(class::Instance)
    metaclass = getfield(class, :metaclass)
    slots = getfield(metaclass, :slots)
    dump(slots)
    idx = findfirst(==(:direct_slots), slots[2])
    getfield(class, :slots)[idx]
end

get_all_slots(instance::Instance) = println("Not Implemented Exception")

get_field_index(instance::Instance, slot_name::Symbol) =
    findfirst(==(slot_name), get_direct_slots(getfield(instance, :metaclass)))
####################################################################

function class_of(instance::Instance)
    getfield(instance, :metaclass)
end

function Base.getproperty(instance::Instance, slot_name::Symbol)
    idx = get_field_index(instance, slot_name)
    getfield(instance, :slots)[idx]
end

function setproperty!(instance::Instance, slot_name::Symbol, value)
    idx = get_field_index(instance, slot_name)
    getfield(instance, :slots)[idx] = value
end

####################################################################
#                             METHODS                              #
####################################################################
allocate_instance(class::Instance) = Instance(class)

function initialize(instance::Instance, initargs)
    dump(getfield(instance, :metaclass))
    for slot_name in get_direct_slots(getfield(instance, :metaclass))
        value = get(initargs, slot_name, missing)
        push!(getfield(instance, :slots), value)
    end
end

new(class; initargs...) =
    let instance = allocate_instance(class)
        initialize(instance, initargs)
        instance
    end

####################################################################

ComplexNumber = new(Class, direct_superclasses=[Object], direct_slots=[:real, :img])
ist = new(ComplexNumber, img=1, real=3)
dump(ist)

class_of(Class) == Class

getproperty(ist, :img)
getproperty(ist, :real)
ist.real

setproperty!(ist, :real, 5634753645763485863)
getproperty(ist, :real)