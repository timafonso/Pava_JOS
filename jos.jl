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

Top = Instance(Class)
Object = Instance(Class)

push!(Class.slots, :Class)              # name
push!(Class.slots, [Object])            # superclasses
push!(Class.slots, CLASS_SLOTS)         # direct slots
push!(Class.slots, [Class, Object, Top])     # cpl

push!(Top.slots, :Top)                  # name
push!(Top.slots, [])                 # superclasses
push!(Top.slots, [])                 # direct slots
push!(Top.slots, [Top])              # cpl

push!(Object.slots, :Object)            # name
push!(Object.slots, [Top])              # superclasses
push!(Object.slots, [])                 # direct slots
push!(Object.slots, [Object, Top])           # cpl


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

function class_of(instance)
    if (typeof(instance) == Instance)
        return getfield(instance, :class)
    end        

    Top
end

function Base.getproperty(instance::Instance, slot_name::Symbol)
    if hasfield(Instance, slot_name)
        getfield(instance, slot_name)
    else
        idx = get_field_index(instance, slot_name)
        getfield(instance, :slots)[idx]
    end
end

function Base.setproperty!(instance::Instance, slot_name::Symbol, value)
    if hasfield(Instance, slot_name)
        setfield!(instance, slot_name, value)
    else
        idx = get_field_index(instance, slot_name)
        getfield(instance, :slots)[idx] = value
    end
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

    # TODO change this to generic function of Class

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

function create_method(generic_function, specializers, procedure)
    (length(generic_function.args) == length(specializers)) || error("Wrong specializers for generic function.")

    multi_method = new(MultiMethod, specializers=specializers, procedure=procedure, generic_function=generic_function)
    push!(generic_function.methods, multi_method)
end

<<<<<<< Updated upstream
function call_effective_method(generic_f, args)
    (length(generic_f.args) == length(args)) || error("Wrong arguments for generic function.")
=======
function get_method_similarity(method, arg_types)
    similarity = 0

    for (specializer, arg_type) in zip(method.specializers, arg_types)
        cpl = specializer.cpl
        idx = findfirst(==(arg_type), cpl)

        if(idx === nothing)
            return nothing
        end

        similarity += idx
    end

    similarity
end

function get_applicable_methods(generic_f, arg_types)
    applicable_methods = []
>>>>>>> Stashed changes

    for method in generic_f.methods
        if !(get_method_similarity(method, arg_types) === nothing)
            push!(applicable_methods, method)
        end
    end

    applicable_methods
end


function call_effective_method(generic_f, args)
    (length(generic_f.args) == length(args)) || error("Wrong arguments for generic function.")

    arg_types = class_of.(args)
    applicable_methods = get_applicable_methods(generic_f, arg_types)

    
    best_method = nothing
    best_similarity = nothing
    for method in generic_f.methods
        similarity = get_method_similarity(method, arg_types)
        if ( (best_similarity === nothing) || (!(similarity === nothing) && similarity < best_similarity) )
            best_method = method
            best_similarity = similarity
        end
    end

    if (best_method === nothing)
        error("No effective method found.")
    end
    best_method.procedure(args...)
end

(generic_f::Instance)(args...) = call_effective_method(generic_f, args)


func = new(GenericFunction, name=:func, args=[:a, :b], methods=[])


####################################################################

####################################################################
#                        PRE-DEFINED METHODS                       #
####################################################################
global print_object = new(GenericFunction, name=:print_object, args=[:obj, :io], methods=[])
create_method(print_object, [Object, Top], (obj, io)->(print(io, "<$((class_of(obj)).name) $(string(objectid(obj), base=62))>")))

function Base.show(io::IO, obj::Instance)
    print_object(obj, io)
end
####################################################################


####################################################################
#                               TESTING                            #
####################################################################

# Creating a class
Num = new(Class, name=:Number, direct_superclasses=[Object], direct_slots=[:value])
# Creating a class that inherits from the previous 
ComplexNumber = new(Class, name=:ComplexNumber, direct_superclasses=[Num, Object], direct_slots=[:real, :img])

Comp1 = new(ComplexNumber, real=1, img=1)
Comp2 = new(ComplexNumber, real=2, img=2)
Numb1 = new(Num, value=30)

# Creating an instance of the previous class and verifying and updating its values

ComplexNumber.direct_slots
ComplexNumber.name
ComplexNumber.direct_superclasses == [Num, Object]

####################################################################
# Code for macros (generic function and methods)
####################################################################
if (!@isdefined add)
    global add = new(GenericFunction, name=:add, args=[:x, :y], methods=[])
end
####################################################################
<<<<<<< Updated upstream
create_method(add, [ComplexNumber, ComplexNumber], (a, b) -> (new(ComplexNumber, real=(a.real + b.real), img=(a.img + b.img))))
=======
create_method(add, [Num, Num], (a,b)->(println("Only numbers")))
create_method(add, [ComplexNumber, Num], (a,b)->(println("complex numbers and num")))
>>>>>>> Stashed changes

c1 = add(Comp1, Comp2)
c2 = add(Numb1, Numb1)
c3 = add(Comp1, Numb1)

Class.cpl
Num.cpl