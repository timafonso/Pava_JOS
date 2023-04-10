global applicable_method_stack = []

#=============== CONSTS =================#
const CLASS_NAME = :name
const DIRECT_SUPERCLASSES = :direct_superclasses
const DIRECT_SLOTS = :direct_slots
const CLASS_CPL = :cpl
const INITFORMS = :initforms
const METACLASS = :metaclass
const CLASS_SLOTS = [CLASS_NAME, DIRECT_SUPERCLASSES, DIRECT_SLOTS, CLASS_CPL, INITFORMS, METACLASS]


#=========== Instance Struct =============#
mutable struct Instance
    class::Instance
    slots::Vector{}  # In classes index 1 is superclasses and index 2 is direct slots, ...
    Instance() = (x = new(); x.class = x; x.slots = []; x)
    Instance(class) = new(class, [])
    Instance(class, slots) = (x = new(); x.class = class; x.slots = slots; x)
end

#=========== Method Call Struct =========#
struct MethodCallStack
    methods::Vector
    args
    generic_function
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

#-------------- Generic Functions and Methods -----------------------
GenericFunction = Instance(Class, [:GenericFunction, [Object], [:name, :args, :methods]]) 
push!(GenericFunction.slots, [GenericFunction, Object, Top]) #cpl
MultiMethod = Instance(Class, [:MultiMethod, [Object], [:specializers, :procedure, :generic_function]])
push!(MultiMethod.slots, [MultiMethod, Object, Top]) #cpl
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

function class_of(instance)
    if (typeof(instance) == Instance)
        return getfield(instance, :class)
    end        

    Top
end

function class_name(instance)
    instance.name
end

function class_direct_slots(instance)
    instance.direct_slots
end

function class_slots(instance)
    get_all_slots(instance)
end

function class_direct_superclasses(instance)
    instance.direct_superclasses
end

function class_cpl(instance)
    instance.cpl
end

function generic_methods(instance)
    instance.methods
end

function method_specializers(instance)
    instance.specializers
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

function is_applicable_method(method, arg_types)
    
    for (specializer, arg_type) in zip(method.specializers, arg_types)
        cpl = arg_type.cpl
        result = findfirst(==(specializer), cpl)

        (result === nothing) && return false
    end
    true
end

function get_applicable_methods(generic_f, arg_types, args)
    applicable_methods = []

    for method in generic_f.methods
        if (is_applicable_method(method, arg_types))
            push!(applicable_methods, method)
        end
    end
    applicable_methods
end

function compare_methods(method_1, method_2, arg_types)

    for (specializer_1, specializer_2 , arg_type) in zip(method_1.specializers, method_2.specializers, arg_types)
        cpl = arg_type.cpl
        depth_1 = findfirst(==(specializer_1), cpl)
        depth_2 = findfirst(==(specializer_2), cpl)

        if(depth_1 < depth_2)
            return true
        end
    end

    return false
end

function call_next_method()
    let method_stack = applicable_method_stack
        (length(method_stack.methods) == 0) && no_applicable_method(method_stack.generic_function, method_stack.args)

        next_method = popfirst!(method_stack.methods)
        next_method.procedure(method_stack.args...)
    end    
end 

function call_effective_method(generic_f, args)
    (length(generic_f.args) == length(args)) || error("Wrong arguments for generic function.")

    arg_types = class_of.(args)
    applicable_methods = get_applicable_methods(generic_f, arg_types, args)

    (length(applicable_methods) == 0) && no_applicable_method(generic_f, args)

    best_methods = sort(applicable_methods, lt=(method_1, method_2)->compare_methods(method_1, method_2, arg_types))
    
    applicable_method_stack_backup = applicable_method_stack
    global applicable_method_stack = MethodCallStack(best_methods, args, generic_f)
    result = call_next_method()
    global applicable_method_stack = applicable_method_stack_backup

    result
end

function no_applicable_method(gf, args)
    error("No applicable method for function $(gf.name) with arguments $(args)")
end

(generic_f::Instance)(args...) = call_effective_method(generic_f, args)

##################### Initialize Instance ##########################
# ALLOCATE INSTANCE ------------------------------------------------
allocate_instance = Instance(GenericFunction, [:allocate_instance, [:arg], []])
# Objects 
mm = Instance(MultiMethod, [[Object], (obj)->(Instance(obj)), allocate_instance])
push!(allocate_instance.methods, mm)
# Classes 
mm = Instance(MultiMethod, [[Class], (cls)->(Instance(cls)), allocate_instance])
push!(allocate_instance.methods, mm)

# INITIALIZE -------------------------------------------------------
initialize = Instance(GenericFunction, [:initialize, [:instance, :initargs], []])
# Objects 
mm = Instance(MultiMethod, [[Object, Top], function (instance, initargs)
                                                for slot_name in get_all_slots(getfield(instance, :class))
                                                    value = get(initargs, slot_name, missing)
                                                    push!(getfield(instance, :slots), value)
                                                end
                                            end

, initialize])
push!(initialize.methods, mm)

# Classes
mm = Instance(MultiMethod, [[Class, Top], function (instance, initargs)
                                                for slot_name in get_direct_slots(getfield(instance, :class))
                                                    value = get(initargs, slot_name, missing)
                                                    if (slot_name == DIRECT_SUPERCLASSES)
                                                        if (value === missing)
                                                            value = [Object]
                                                        elseif (Object ∉ value)
                                                            push!(value, Object)                                                            
                                                        end
                                                    end

                                                    push!(getfield(instance, :slots), value)
                                                end

                                                cpl = compute_cpl(instance)
                                                setproperty!(instance, CLASS_CPL, cpl)

                                                for slot_name in get_indirect_slots(getfield(instance, :class))
                                                    value = get(initargs, slot_name, missing)
                                                    push!(getfield(instance, :slots), value)
                                                end
                                            end
, initialize])
push!(initialize.methods, mm)

new(class; initargs...) =
    let instance = allocate_instance(class)
        initialize(instance, initargs)
        instance
    end

####################################################################


####################################################################
#                         GENERIC FUNCTIONS                        #
####################################################################
function create_method(generic_function, specializers, procedure)
    (length(generic_function.args) == length(specializers)) || error("Wrong specializers for generic function.")

    multi_method = new(MultiMethod, specializers=specializers, procedure=procedure, generic_function=generic_function)

    if (multi_method.specializers ∉ method_specializers.(generic_function.methods))
        push!(generic_function.methods, multi_method)
    end
end

func = new(GenericFunction, name=:func, args=[:a, :b], methods=[])


####################################################################

####################################################################
#                        PRE-DEFINED METHODS                       #
####################################################################

############################# Print ################################
global print_object = new(GenericFunction, name=:print_object, args=[:obj, :io], methods=[])

# Objects ----------------------------------------------------------
create_method(print_object, [Object, Top], (obj, io)->(print(io, "<$((class_of(obj)).name) $(string(objectid(obj), base=62))>")))

# Classes ----------------------------------------------------------
create_method(print_object, [Class, Top], (cls, io)->(print(io, "<$(class_of(cls).name) $(cls.name)>")))

# Generic Functions ------------------------------------------------
create_method(print_object, [GenericFunction, Top], (gf, io)->(print(io, "<GenericFunction $(gf.name) with $(length(gf.methods)) methods>")))

# Multi Methods ----------------------------------------------------
create_method(print_object, [MultiMethod, Top], (mm, io)->(names = getproperty.(mm.specializers, :name); print(io, "<MultiMethod $(mm.generic_function.name)($(join(names, ", ")))>")))

function Base.show(io::IO, obj::Instance)
    print_object(obj, io)
end
####################################################################





####################################################################

####################################################################
#                               MACROS                             #
####################################################################
macro defclass(class, superclasses, direct_slots)
    direct_superclasses = superclasses.args
    direct_slot_names = direct_slots.args

    class_name = Expr(:quote, class) 
    quote
        global $class = new(Class, name=$class_name, direct_superclasses=$direct_superclasses, direct_slots=$direct_slot_names)
    end
end

macro defgeneric(generic_function)
   
    name = generic_function.args[1]
    arguments = generic_function.args[2:end]

    generic_function_name = Expr(:quote, name)

    quote
        global $name = new(GenericFunction, name=$generic_function_name, args=$arguments, methods=[])
    end
end

macro defmethod(method)
    # index 1 method name arguments and argument arg_types
    # index 2 procedure
    # create_method(get_device_color, [ColoredPrinter], (cp)->(cp.ink))
    name = method.args[1].args[1]
    generic_function_name = Expr(:quote, name)

    arguments = []
    specializers = []

    for expr in method.args[1].args[2:end]
        push!(arguments, expr.args[1])
        push!(specializers, expr.args[2])
    end

    procedure = method.args[2]
    quote
        if (!@isdefined $name)
            global $name = new(GenericFunction, name=$generic_function_name, args=$arguments, methods=[])
        end
        #create_method($name, $specializers, (arguments...)->$(procedure))
    end
end

@defclass(ComplexNumber, [], [real, imag])

@defgeneric add(a, b)
@defmethod add(a::ComplexNumber, b::ComplexNumber) =
    new(ComplexNumber, real=(a.real + b.real), imag=(a.imag + b.imag))


show(add.methods)
c1 = new(ComplexNumber, real=1, imag=2)
c2 = new(ComplexNumber, real=1, imag=2)
add(c1, c2)

####################################################################
#                               TESTING                            #
####################################################################

Shape = new(Class, name=:Shape, direct_slots=[])
Device = new(Class, name=:Device, direct_superclasses=[Object], direct_slots=[])
Line = new(Class, name=:Line, direct_superclasses=[Shape, Object], direct_slots=[:from, :to])
Circle = new(Class, name=:Circle, direct_superclasses=[Shape, Object], direct_slots=[:center, :radius])
Screen = new(Class, name=:Screen, direct_superclasses=[Device, Object], direct_slots=[])
Printer = new(Class, name=:Printer, direct_superclasses=[Device, Object], direct_slots=[])
ColoredPrinter = new(Class, name=:ColoredPrinter, direct_superclasses=[Printer, Object], direct_slots=[:ink])
ColorMixin = new(Class, name=:ColorMixin, direct_superclasses=[Object], direct_slots=[:color])
ColoredLine = new(Class, name=:ColoredLine, direct_superclasses=[ColorMixin, Line, Object], direct_slots=[])
ColoredCircle = new(Class, name=:ColoredCircle, direct_superclasses=[ColorMixin, Circle, Object], direct_slots=[])

@defgeneric get_device_color(cp)
create_method(get_device_color, [ColoredPrinter], (cp)->(cp.ink))

_set_device_color! = new(GenericFunction, name=:_set_device_color!, args=[:cp, :c], methods=[])
set_device_color! = new(GenericFunction, name=:set_device_color!, args=[:cp, :c], methods=[])
create_method(_set_device_color!, [ColoredPrinter, Top], (cp, c)->(cp.ink = c))
create_method(set_device_color!, [ColoredPrinter, Top], (cp, c)->(println("Changing printer ink color to $c"); _set_device_color!(cp, c)))

draw = new(GenericFunction, name=:draw, args=[:shape, :device], methods=[])
create_method(draw, [Line, Screen], (l, s)->println("Drawing a Line on Screen"))
create_method(draw, [Circle, Screen], (c, s)->println("Drawing a Circle on Screen"))
create_method(draw, [Line, Printer], (l, p)->println("Drawing a Line on Printer"))
create_method(draw, [Circle, Printer], (c, p)->println("Drawing a Circle on Printer"))
create_method(draw, [ColorMixin, Device],  function (cm, d) 
                                                previous_color = get_device_color(d)
                                                set_device_color!(d, cm.color)
                                                call_next_method()
                                                set_device_color!(d, previous_color)
                                           end)

show(draw.methods)

let devices = [new(Screen), new(Printer)],
    shapes = [new(Line), new(Circle)]
    for device in devices
        for shape in shapes
            draw(shape, device)
        end
    end
end

let shapes = [new(Line), new(ColoredCircle, color=:red), new(ColoredLine, color=:blue)],
    printer = new(ColoredPrinter, ink=:black)
    for shape in shapes
        draw(shape, printer)
    end
end
####################################################################
#                       Expected Result                            #
####################################################################

#Drawing a Line on Screen
#Drawing a Circle on Screen
#Drawing a Line on Printer
#Drawing a Circle on Printer
