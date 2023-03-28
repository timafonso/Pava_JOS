#=============== CONSTS =================#
const CLASS_SLOTS = [:name, :direct_superclasses, :direct_slots]


#=========== Instance Struct =============#
mutable struct Instance
    class::Instance
    slots::Vector{}  # In classes index 1 is superclasses and index 2 is direct slots
    Instance() = new()
    Instance(class) = new(class, [])
end

####################################################################
#                         BASE CLASSES                             #
####################################################################

#---------------------- Class & Object -----------------------------
Class = Instance()
Class.class = Class
Class.slots = []

Object = Instance()
Object.class = Class

push!(Class.slots, :Class)
push!(Class.slots, [Object])
push!(Class.slots, CLASS_SLOTS)

####################################################################

####################################################################
#                            UTILS                                 #
####################################################################
function get_direct_slots(class::Instance)
    idx = findfirst(==(:direct_slots), CLASS_SLOTS)
    getfield(class, :slots)[idx]
end

get_all_slots(instance::Instance) = println("Not Implemented Exception")

get_field_index(instance::Instance, slot_name::Symbol) =
    findfirst(==(slot_name), get_direct_slots(getfield(instance, :class)))
####################################################################

function class_of(instance::Instance)
    getfield(instance, :class)
end

function Base.getproperty(instance::Instance, slot_name::Symbol)
    idx = get_field_index(instance, slot_name)
    getfield(instance, :slots)[idx]
end

function Base.setproperty!(instance::Instance, slot_name::Symbol, value)
    idx = get_field_index(instance, slot_name)
    getfield(instance, :slots)[idx] = value
end

####################################################################
#                             METHODS                              #
####################################################################
allocate_instance(class::Instance) = Instance(class)

function initialize(instance::Instance, initargs)
    dump(getfield(instance, :class))
    for slot_name in get_direct_slots(getfield(instance, :class))
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


####################################################################
#                         GENERIC FUNCTIONS                        #
####################################################################


####################################################################



ComplexNumber = new(Class, name=:ComplexNumber, direct_superclasses=[Object], direct_slots=[:real, :img])
ist = new(ComplexNumber, img=1, real=3)
dump(ist)

class_of(Class) == Class

getproperty(ist, :img)
getproperty(ist, :real)
ist.real
ist.real += 5
setproperty!(ist, :real, 5634753645763485863)
getproperty(ist, :real)

