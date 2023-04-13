global applicable_method_stack = []

#=============== CONSTS =================#
const CLASS_NAME = :name
const DIRECT_SUPERCLASSES = :direct_superclasses
const DIRECT_SLOTS = :direct_slots
const CLASS_CPL = :cpl
const INITFORMS = :initforms
const GETTERS = :getters
const SETTERS = :setters
const CLASS_SLOTS = [DIRECT_SLOTS, CLASS_NAME, DIRECT_SUPERCLASSES, CLASS_CPL, INITFORMS, GETTERS, SETTERS]
const CLASS_DIRECT_SLOTS_IDX = findfirst(==(DIRECT_SLOTS), CLASS_SLOTS)
const CLASS_GETTERS_IDX = findfirst(==(GETTERS), CLASS_SLOTS)
const CLASS_SETTERS_IDX = findfirst(==(SETTERS), CLASS_SLOTS)

const METACLASS = :metaclass
const CLASS_OPTIONS_READER = :reader
const CLASS_OPTIONS_WRITER = :writer
const CLASS_OPTIONS_INITFORM = :initform

#=========== Instance Struct =============#
mutable struct Instance
    slots::Vector{}  # In classes index 1 is superclasses and index 2 is direct slots, ...
    class::Instance
    Instance() = (x = new(); x.class = x; x.slots = []; x)
    Instance(class) = (x = new(); x.class = class; x.slots = []; x)
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

push!(Class.slots, CLASS_SLOTS)                         # direct slots
push!(Class.slots, :Class)                              # name
push!(Class.slots, [Object])                            # superclasses
push!(Class.slots, [Class, Object, Top])                # cpl
push!(Class.slots, [missing for _ in CLASS_SLOTS])      # initforms
push!(Class.slots, Dict())                                  # getters
push!(Class.slots, Dict())                                  # setters

push!(Top.slots, [])                    # direct slots
push!(Top.slots, :Top)                  # name
push!(Top.slots, [])                    # superclasses
push!(Top.slots, [Top])                 # cpl
push!(Top.slots, [])                    # initforms
push!(Top.slots, Dict())                  # getters
push!(Top.slots, Dict())                  # setters



push!(Object.slots, [])                 # direct slots
push!(Object.slots, :Object)            # name
push!(Object.slots, [Top])              # superclasses
push!(Object.slots, [Object, Top])           # cpl
push!(Object.slots, [])                 # initforms
push!(Object.slots, Dict())                  # getters
push!(Object.slots, Dict())                  # setters

#-------------- Generic Functions and Methods -----------------------
GENERIC_FUNCTION_SLOTS = [:name, :args, :methods]
GenericFunction = Instance(Class, [GENERIC_FUNCTION_SLOTS, :GenericFunction, [Object]])
push!(GenericFunction.slots, [GenericFunction, Object, Top]) #cpl
push!(GenericFunction.slots, [missing, missing, missing]) #initforms
push!(GenericFunction.slots, Dict())                  # getters
push!(GenericFunction.slots, Dict())                  # setters

MULTI_METHOD_SLOTS = [:specializers, :procedure, :generic_function]
MultiMethod = Instance(Class, [MULTI_METHOD_SLOTS, :MultiMethod, [Object]])
push!(MultiMethod.slots, [MultiMethod, Object, Top])    #cpl
push!(MultiMethod.slots, [missing, missing, missing])   #initforms
push!(MultiMethod.slots, Dict())                    # getters
push!(MultiMethod.slots, Dict())                    # setters


####################################################################
#                            UTILS                                 #
####################################################################
function get_slot(instance::Instance, field_name)
    class = getfield(instance, :class)
    if (class === Class)
        getters = getfield(Class, :slots)[CLASS_GETTERS_IDX]
    else
        getters = get_slot(class, GETTERS)
    end
    return getters[field_name](instance)
end

function set_slot(instance::Instance, field_name, value)
    class = getfield(instance, :class)
    setters = get_slot(class, SETTERS)
    setters[field_name](instance, value)
end


function get_direct_slots(class::Instance)
    get_slot(class, DIRECT_SLOTS)
end

function get_direct_initforms(class::Instance)
    get_slot(class, INITFORMS)
end

function get_direct_slots_and_initforms(class::Instance)
    (get_direct_slots(class), get_direct_initforms(class))
end

function get_indirect_slots(class::Instance, get_initforms::Bool=false)
    cpl = get_slot(class, CLASS_CPL)

    indirect_slots = []
    indirect_initforms = []
    for class_cpl in cpl
        if class_cpl == class
            continue
        end

        if get_initforms
            slots, initforms = get_direct_slots_and_initforms(class_cpl)
            indirect_initforms = vcat(indirect_initforms, initforms)
        else
            slots = get_direct_slots(class_cpl)
        end

        indirect_slots = vcat(indirect_slots, slots)
    end

    get_initforms ? (indirect_slots, indirect_initforms) : indirect_slots
end

function get_indirect_slots_and_initforms(class::Instance)
    get_indirect_slots(class, true)
end


function get_all_slots_and_initforms(class::Instance)
    slots, initforms = get_direct_slots_and_initforms(class)
    indirect_slots, indirect_initforms = get_indirect_slots_and_initforms(class)
    vcat(slots, indirect_slots), vcat(initforms, indirect_initforms)
end

function get_all_slots(class::Instance)
    vcat(get_direct_slots(class), get_indirect_slots(class))
end

function Base.getproperty(instance::Instance, slot_name::Symbol)
    if hasfield(Instance, slot_name)
        getfield(instance, slot_name)
    else
        get_slot(instance, slot_name)
    end
end

function Base.setproperty!(instance::Instance, slot_name::Symbol, value)
    if hasfield(Instance, slot_name)
        setfield!(instance, slot_name, value)
    else
        set_slot(instance, slot_name, value)
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
#                         Generic (BOOTSTRAPPING)                  #
####################################################################

#-------------- Bootstrapping Getters and Setters -----------------------
function _bootstrap_class_getters_and_setters(class::Instance, slot_names)
    class_slots = getfield(class, :slots)

    for i in eachindex(slot_names)
        class_slots[CLASS_GETTERS_IDX][slot_names[i]] = (inst) -> (getfield(inst, :slots)[i])
        class_slots[CLASS_SETTERS_IDX][slot_names[i]] = (inst, v) -> (println("Setter $(slot_names[i]) ; idx: $i"); println("getfield(inst, :slots)[$i] = $v)"); getfield(inst, :slots)[i] = v)
    end
end

# Class
_bootstrap_class_getters_and_setters(Class, CLASS_SLOTS)

# GenericFunctions
generic_functions_slots_names = vcat(GENERIC_FUNCTION_SLOTS, CLASS_SLOTS)
_bootstrap_class_getters_and_setters(GenericFunction, generic_functions_slots_names)

# MultiMethods
multi_method_slots_names = vcat(MULTI_METHOD_SLOTS, CLASS_SLOTS)
_bootstrap_class_getters_and_setters(MultiMethod, multi_method_slots_names)

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

function get_applicable_methods(generic_f, arg_types)
    applicable_methods = []

    for method in generic_f.methods
        if (is_applicable_method(method, arg_types))
            push!(applicable_methods, method)
        end
    end
    applicable_methods
end

function compare_methods(method_1, method_2, arg_types)

    for (specializer_1, specializer_2, arg_type) in zip(method_1.specializers, method_2.specializers, arg_types)
        cpl = arg_type.cpl
        depth_1 = findfirst(==(specializer_1), cpl)
        depth_2 = findfirst(==(specializer_2), cpl)

        if (depth_1 < depth_2)
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
    applicable_methods = get_applicable_methods(generic_f, arg_types)

    (length(applicable_methods) == 0) && no_applicable_method(generic_f, args)

    best_methods = sort(applicable_methods, lt=(method_1, method_2) -> compare_methods(method_1, method_2, arg_types))

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
mm = Instance(MultiMethod, [[Object], (obj) -> (Instance(obj)), allocate_instance])
push!(allocate_instance.methods, mm)
# Classes 
mm = Instance(MultiMethod, [[Class], (cls) -> (Instance(cls)), allocate_instance])
push!(allocate_instance.methods, mm)

# INITIALIZE -------------------------------------------------------
initialize = Instance(GenericFunction, [:initialize, [:instance, :initargs], []])
# Objects 
mm = Instance(MultiMethod, [[Object, Top], function (instance, initargs)
        slots, initforms = get_all_slots_and_initforms(getfield(instance, :class))
        for (slot_name, initform) in zip(slots, initforms)
            value = get(initargs, slot_name, initform)
            push!(getfield(instance, :slots), value)
        end
    end, initialize])
push!(initialize.methods, mm)

# Classes
mm = Instance(MultiMethod, [[Class, Top], function (instance, initargs)
        slots, initforms = get_direct_slots_and_initforms(getfield(instance, :class))
        for (slot_name, initform) in zip(slots, initforms)
            value = get(initargs, slot_name, initform)
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

        #slots, initforms = get_indirect_slots_and_initforms(getfield(instance, :class))
        #for (slot_name, initform) in zip(slots, initforms)
        #    value = get(initargs, slot_name, initform)
        #    push!(getfield(instance, :slots), value)
        #end
    end, initialize])
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

# func = new(GenericFunction, name=:func, args=[:a, :b], methods=[])


####################################################################

####################################################################
#                        PRE-DEFINED METHODS                       #
####################################################################

############################# Print ################################

global print_object = new(GenericFunction, name=:print_object, args=[:obj, :io], methods=[])

# Objects ----------------------------------------------------------
create_method(print_object, [Object, Top], (obj, io) -> (print(io, "<$((class_of(obj)).name) $(string(objectid(obj), base=62))>")))

# Classes ----------------------------------------------------------
create_method(print_object, [Class, Top], (cls, io) -> (print(io, "<$(class_of(cls).name) $(cls.name)>")))

# Generic Functions ------------------------------------------------
create_method(print_object, [GenericFunction, Top], (gf, io) -> (print(io, "<GenericFunction $(gf.name) with $(length(gf.methods)) methods>")))

# Multi Methods ----------------------------------------------------
create_method(print_object, [MultiMethod, Top], (mm, io) -> (names = getproperty.(mm.specializers, :name); print(io, "<MultiMethod $(mm.generic_function.name)($(join(names, ", ")))>")))

function Base.show(io::IO, obj::Instance)
    print_object(obj, io)
end
####################################################################

####################################################################

####################################################################
#                               MACROS                             #
####################################################################

# @defclass(Person, [],
#       [[name='', reader=get_name, writer=set_name!],
#       [age, reader=get_age, writer=set_age!, initform=0],
#       [friend, reader=get_friend, writer=set_friend!]],

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

    prototype = method.args[1]
    body = method.args[2].args[2]

    arguments = []
    specializers = []

    for parameter in prototype.args[2:end]
        if typeof(parameter) === Symbol
            push!(arguments, parameter)
            push!(specializers, Top)
        else
            push!(arguments, parameter.args[1])
            push!(specializers, parameter.args[2])
        end
    end

    quote
        if (!@isdefined $name)
            global $name = new(GenericFunction, name=$generic_function_name, args=$arguments, methods=[])
        end
        create_method($name, [$(specializers...),], function ($(arguments...),)
            $(body)
        end)
    end
end

macro defclass(class, superclasses, direct_slots, metaclass_expr=missing)
    class_name = Expr(:quote, class)
    direct_superclasses = superclasses.args

    metaclass = :Class
    if (typeof(metaclass_expr) == Expr && metaclass_expr.args[1] == METACLASS)
        metaclass = metaclass_expr.args[2]
    end

    direct_slot_names = []
    direct_slot_initforms = []
    method_definitions = []

    for slot_def in direct_slots.args
        initform = missing
        slot_name = slot_def

        if (typeof(slot_def) == Expr && slot_def.head == :vect)
            slot_name = slot_def.args[1]
            options = slot_def.args[2:end]

            if typeof(slot_name) == Expr
                initform = slot_name.args[2]
                slot_name = slot_name.args[1]
            end

            for option in options
                option_name = option.args[1]
                option_value = option.args[2]

                if option_name == CLASS_OPTIONS_INITFORM
                    initform = option_value
                elseif option_name == CLASS_OPTIONS_READER
                    reader_method = quote
                        @defmethod $(option_value)(o::$class) = o.$(slot_name)
                    end
                    push!(method_definitions, reader_method)
                elseif option_name == CLASS_OPTIONS_WRITER
                    writer_method = quote
                        @defmethod $(option_value)(o::$class, v) = o.$(slot_name) = v
                    end
                    push!(method_definitions, writer_method)
                end
            end
        end

        push!(direct_slot_names, slot_name)
        push!(direct_slot_initforms, initform)
    end


    quote
        global $class = new($metaclass, $CLASS_NAME=$class_name, $DIRECT_SUPERCLASSES=[$(direct_superclasses...),], $DIRECT_SLOTS=$direct_slot_names, $INITFORMS=$direct_slot_initforms)

        $(method_definitions...)

        $class
    end
end


macro defbuiltinclass(type)
    !@isdefined(type) && error("Builtin Julia type [$type] does not exist.")
    class_name = Symbol("_$type")
    esc(quote
        @defclass($class_name, [Top], [])
        function class_of(i::$type)
            return $class_name
        end
    end)
end

####################################################################
#                               TESTING                            #
####################################################################




# Shape = new(Class, name=:Shape, direct_slots=[])
# Device = new(Class, name=:Device, direct_superclasses=[Object], direct_slots=[])
# Line = new(Class, name=:Line, direct_superclasses=[Shape, Object], direct_slots=[:from, :to])
# Circle = new(Class, name=:Circle, direct_superclasses=[Shape, Object], direct_slots=[:center, :radius])
# Screen = new(Class, name=:Screen, direct_superclasses=[Device, Object], direct_slots=[])
# Printer = new(Class, name=:Printer, direct_superclasses=[Device, Object], direct_slots=[])
# ColoredPrinter = new(Class, name=:ColoredPrinter, direct_superclasses=[Printer, Object], direct_slots=[:ink])
# ColorMixin = new(Class, name=:ColorMixin, direct_superclasses=[Object], direct_slots=[:color])
# ColoredLine = new(Class, name=:ColoredLine, direct_superclasses=[ColorMixin, Line, Object], direct_slots=[])
# ColoredCircle = new(Class, name=:ColoredCircle, direct_superclasses=[ColorMixin, Circle, Object], direct_slots=[])

# @defgeneric get_device_color(cp)
# create_method(get_device_color, [ColoredPrinter], (cp) -> (cp.ink))

# _set_device_color! = new(GenericFunction, name=:_set_device_color!, args=[:cp, :c], methods=[])
# set_device_color! = new(GenericFunction, name=:set_device_color!, args=[:cp, :c], methods=[])
# create_method(_set_device_color!, [ColoredPrinter, Top], (cp, c) -> (cp.ink = c))
# create_method(set_device_color!, [ColoredPrinter, Top], (cp, c) -> (println("Changing printer ink color to $c"); _set_device_color!(cp, c)))

# draw = new(GenericFunction, name=:draw, args=[:shape, :device], methods=[])
# create_method(draw, [Line, Screen], (l, s) -> println("Drawing a Line on Screen"))
# create_method(draw, [Circle, Screen], (c, s) -> println("Drawing a Circle on Screen"))
# create_method(draw, [Line, Printer], (l, p) -> println("Drawing a Line on Printer"))
# create_method(draw, [Circle, Printer], (c, p) -> println("Drawing a Circle on Printer"))
# create_method(draw, [ColorMixin, Device], function (cm, d)
#     previous_color = get_device_color(d)
#     set_device_color!(d, cm.color)
#     call_next_method()
#     set_device_color!(d, previous_color)
# end)

# show(draw.methods)

# let devices = [new(Screen), new(Printer)],
#     shapes = [new(Line), new(Circle)]

#     for device in devices
#         for shape in shapes
#             draw(shape, device)
#         end
#     end
# end

# let shapes = [new(Line), new(ColoredCircle, color=:red), new(ColoredLine, color=:blue)],
#     printer = new(ColoredPrinter, ink=:black)

#     for shape in shapes
#         draw(shape, printer)
#     end
# end

# #--------------------------------------------------------------------------

# @defclass(Person, [], [[name, reader = get_name, writer = set_name!],
#     [age, reader = get_age, writer = set_age!, initform = 2],
#     [friend = "Jorge", reader = get_friend, writer = set_friend!]])


# p = new(Person, name='a')
# display(p.slots)

# @defgeneric add(a, b)
# @defmethod add(a::ComplexNumber, b::ComplexNumber) =
#     new(ComplexNumber, real=(a.real + b.real), imag=(a.imag + b.imag))

# show(add.methods)
# c1 = new(ComplexNumber, real=1, imag=2)
# c2 = new(ComplexNumber, real=1, imag=2)
# add(c1, c2)

# #--------------------------------------------------------------------------

# @macroexpand @defbuiltinclass(Int64)
# @defbuiltinclass(Int64)
# @defbuiltinclass(String)


# class_of(1)
# class_of("Dragon")


# #--------------------------------------------------------------------------

# @macroexpand @defclass(MoreComplexNumber, [ComplexNumber], [superreal])
# @defclass(MoreComplexNumber, [ComplexNumber], [superreal])
# @defclass(MoreComplexNumber2, [MoreComplexNumber, ComplexNumber], [superreal])

# class_direct_slots(MoreComplexNumber2)


# ####################################################################
# #                       Expected Result                            #
# ####################################################################

# #Drawing a Line on Screen
# #Drawing a Circle on Screen
# #Drawing a Line on Printer
# #Drawing a Circle on Printer
