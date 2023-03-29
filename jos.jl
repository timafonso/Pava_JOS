#=============== CONSTS =================#
const CLASS_NAME = :name
const DIRECT_SUPERCLASSES = :direct_superclasses
const DIRECT_SLOTS = :direct_slots
const CLASS_CPL = :cpl
const CLASS_SLOTS = [CLASS_NAME, DIRECT_SUPERCLASSES, DIRECT_SLOTS, CLASS_CPL]


#=========== Instance Struct =============#
mutable struct Instance
    class::Instance
    slots::Vector{}  # In classes index 1 is superclasses and index 2 is direct slots, ...
    Instance() = (x = new(); x.class = x; x.slots = []; x)
    Instance(class) = new(class, [])
end

####################################################################
#                         BASE CLASSES (BOOTSTRAPPING)             #
####################################################################

#---------------------- Class & Object -----------------------------
Class = Instance()
# Class.class = Class
# Class.slots = []

Object = Instance(Class)

push!(Class.slots, :Class)              # name
push!(Class.slots, [Object])            # superclasses
push!(Class.slots, CLASS_SLOTS)         # direct slots
push!(Class.slots, [Class, Object])     # cpl

push!(Object.slots, :Object)            # name
push!(Object.slots, [])                 # superclasses
push!(Object.slots, [])                 # direct slots
push!(Class.slots, [Object])     # cpl


####################################################################

####################################################################
#                            UTILS                                 #
####################################################################
function get_direct_slots(class::Instance)
    idx = findfirst(==(DIRECT_SLOTS), CLASS_SLOTS)
    getfield(class, :slots)[idx]
end
function get_indirect_slots(class::Instance)
    idx = findfirst(==(CLASS_CPL), CLASS_SLOTS)
    cpl = getfield(class, :slots)[idx]

    indirect_slots = []
    for class_cpl in cpl
        if class_cpl == class
            continue
        end

        indirect_slots = vcat(indirect_slots, get_direct_slots(class_cpl))
    end

    indirect_slots
end

function get_all_slots(class::Instance)
    vcat(get_direct_slots(class), get_indirect_slots(class))
end

function get_field_index(instance::Instance, slot_name::Symbol)
    findfirst(==(slot_name), get_all_slots(getfield(instance, :class)))
end

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

function compute_cpl(class::Instance)
    cpl = []
    queue = [class]

    while !isempty(queue)
        value = popfirst!(queue)
        if (value ∉ cpl)
            push!(cpl, value)
            for superclass in value.direct_superclasses
                push!(queue, superclass)
            end
        end
    end

    cpl

end

####################################################################
#                             METHODS                              #
####################################################################
allocate_instance(class::Instance) = Instance(class)

function initialize(instance::Instance, initargs)

    for slot_name in get_direct_slots(getfield(instance, :class))
        value = get(initargs, slot_name, missing)
        push!(getfield(instance, :slots), value)
    end

    if getfield(instance, :class) == Class
        cpl = compute_cpl(instance)
        setproperty!(instance, CLASS_CPL, cpl)
    end


    for slot_name in get_indirect_slots(getfield(instance, :class))
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

GenericFunction = new(Class, direct_superclasses=[Object], direct_slots=[:name, :args, :methods])
MultiMethod = new(Class, direct_superclasses=[Object], direct_slots=[:specializers, :procedure, :generic_function])

function call_effective_method(f, args)


end

(f::Instance)(args...) = call_effective_method(f, args...)


func = new(GenericFunction, name=:func, args=[:a, :b], methods=[])


####################################################################


Num = new(Class, name=:Number, direct_superclasses=[Object], direct_slots=[:value])
ComplexNumber = new(Class, name=:ComplexNumber, direct_superclasses=[Num, Object], direct_slots=[:real, :img])
ist = new(ComplexNumber, img=1, value=27, real=3)
dump(ist)

class_of(Class) == Class

getproperty(ist, :img)
getproperty(ist, :real)
ist.real
ist.real += 5
ist.value
setproperty!(ist, :real, 5634753645763485863)
getproperty(ist, :real)

