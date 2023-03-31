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

function get_method_similarity(method, arg_types)
    similarity = 0

    for (specializer, arg_type) in zip(method.specializers, arg_types)
        cpl = arg_type.cpl
        idx = findfirst(==(specializer), cpl)

        if(idx === nothing)
            return nothing
        end

        similarity += idx
    end

    similarity
end

function get_applicable_methods(generic_f, arg_types)
    applicable_methods = []

    for method in generic_f.methods
        if (!(get_method_similarity(method, arg_types) === nothing))
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
    for method in applicable_methods
        similarity = get_method_similarity(method, arg_types)
        if ( (best_similarity === nothing) || (similarity < best_similarity) )
            best_method = method
            best_similarity = similarity
        end
    end

    if (best_method === nothing)
        error("ERROR: No applicable method for function $(generic_f.name) with arguments $(args)")
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

Shape = new(Class, direct_superclasses=[Object], direct_slots=[:name, :args, :methods])
Device = new(Class, direct_superclasses=[Object], direct_slots=[:name, :args, :methods])
Line = new(Class, direct_superclasses=[Shape, Object], direct_slots=[:from, :to])
Circle = new(Class, direct_superclasses=[Shape, Object], direct_slots=[:center, :radius])
Screen = new(Class, direct_superclasses=[Device, Object], direct_slots=[])
Printer = new(Class, direct_superclasses=[Device, Object], direct_slots=[])

draw = new(GenericFunction, name=:draw, args=[:shape, :device], methods=[])
create_method(draw, [Line, Screen], (l, s)->println("Drawing a Line on Screen"))
create_method(draw, [Circle, Screen], (c, s)->println("Drawing a Circle on Screen"))
create_method(draw, [Line, Printer], (l, p)->println("Drawing a Line on Printer"))
create_method(draw, [Circle, Printer], (c, p)->println("Drawing a Circle on Printer"))

let devices = [new(Screen), new(Printer)],
    shapes = [new(Line), new(Circle)]
    for device in devices
        for shape in shapes
            draw(shape, device)
        end
    end
end

####################################################################
#                       Expected Result                            #
####################################################################

#Drawing a Line on Screen
#Drawing a Circle on Screen
#Drawing a Line on Printer
#Drawing a Circle on Printer
