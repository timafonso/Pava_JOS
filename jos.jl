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

const GENERIC_FUNCTION_NAME = :name
const GENERIC_FUNCTION_ARGS = :args
const GENERIC_FUNCTION_METHODS = :methods
GENERIC_FUNCTION_SLOTS = [GENERIC_FUNCTION_NAME, GENERIC_FUNCTION_ARGS, GENERIC_FUNCTION_METHODS]

const MULTI_METHOD_SPECIALIZERS = :specializers
const MULTI_METHOD_PROCEDURE = :procedure
const MULTI_METHOD_GENERIC_FUNCTION = :generic_function
MULTI_METHOD_SLOTS = [MULTI_METHOD_SPECIALIZERS, MULTI_METHOD_PROCEDURE, MULTI_METHOD_GENERIC_FUNCTION]

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
GenericFunction = Instance(Class, [GENERIC_FUNCTION_SLOTS, :GenericFunction, [Object]])
push!(GenericFunction.slots, [GenericFunction, Object, Top]) #cpl
push!(GenericFunction.slots, [missing, missing, missing]) #initforms
push!(GenericFunction.slots, Dict())                  # getters
push!(GenericFunction.slots, Dict())                  # setters

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

function get_all_slots(class::Instance)
    compute_slots(class)
end

function get_all_initforms(class::Instance)
    vcat(map(class_initforms, class_cpl(class))...)
end

function get_all_slots_and_initforms(instance::Instance)
    slots = get_all_slots(instance)
    initforms = get_all_initforms(instance)
    return (slots, initforms)
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
    getproperty(instance, CLASS_NAME)
end

function class_direct_slots(instance)
    getproperty(instance, DIRECT_SLOTS)
end

function class_initforms(instance)
    getproperty(instance, INITFORMS)
end

function class_slots(instance)
    get_all_slots(instance)
end

function class_direct_superclasses(instance)
    getproperty(instance, DIRECT_SUPERCLASSES)
end

function class_cpl(instance)
    getproperty(instance, CLASS_CPL)
end

function generic_methods(instance)
    getproperty(instance, GENERIC_FUNCTION_METHODS)
end

function method_specializers(instance)
    getproperty(instance, MULTI_METHOD_SPECIALIZERS)
end

# ------------------------------------------------------------------
function add_method(generic_function, multi_method)
    key = (map(x -> x.name, multi_method.specializers)...,)
    methods = generic_function.methods
    methods[key] = multi_method
end

####################################################################
#                         Generic (BOOTSTRAPPING)                  #
####################################################################

#-------------- Bootstrapping Getters and Setters -----------------------
function _bootstrap_class_getters_and_setters(class::Instance, slot_names)
    class_slots = getfield(class, :slots)

    for i in eachindex(slot_names)
        class_slots[CLASS_GETTERS_IDX][slot_names[i]] = (inst) -> (getfield(inst, :slots)[i])
        class_slots[CLASS_SETTERS_IDX][slot_names[i]] = (inst, v) -> (getfield(inst, :slots)[i] = v)
    end
end

# Class
_bootstrap_class_getters_and_setters(Class, CLASS_SLOTS)

# GenericFunctions
_bootstrap_class_getters_and_setters(GenericFunction, GENERIC_FUNCTION_SLOTS)

# MultiMethods
_bootstrap_class_getters_and_setters(MultiMethod, MULTI_METHOD_SLOTS)

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

    for (_, method) in generic_f.methods
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
allocate_instance = Instance(GenericFunction, [:allocate_instance, [:arg], Dict()])
# Objects 
mm = Instance(MultiMethod, [[Object], (obj) -> (Instance(obj)), allocate_instance])
add_method(allocate_instance, mm)
# Classes 
mm = Instance(MultiMethod, [[Class], (cls) -> (Instance(cls)), allocate_instance])
add_method(allocate_instance, mm)

# COMPUTE CPL -------------------------------------------------------
compute_cpl = Instance(GenericFunction, [:compute_cpl, [:class], Dict()])
# Class 
mm = Instance(MultiMethod, [[Class], function (class)
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
    end, compute_cpl])
add_method(compute_cpl, mm)

# COMPUTE GETTERS AND SETTERS -------------------------------------------------------
compute_getter_and_setter = Instance(GenericFunction,
    [:compute_getter_and_setter, [:class, :slot, :idx], Dict()])
# Class 
mm = Instance(MultiMethod, [[Class, Top, Top], function (class, slot, idx)
        getter = (inst) -> (getfield(inst, :slots)[idx])
        setter = (inst, v) -> (getfield(inst, :slots)[idx] = v)
        return (getter, setter)
    end, compute_getter_and_setter])
add_method(compute_getter_and_setter, mm)

# COMPUTE Slots -------------------------------------------------------
compute_slots = Instance(GenericFunction, [:compute_slots, [:class], Dict()])
# Class 
mm = Instance(MultiMethod, [[Class], function (class)
        vcat(map(class_direct_slots, class_cpl(class))...)
    end, compute_slots])
add_method(compute_slots, mm)

# INITIALIZE -------------------------------------------------------
initialize = Instance(GenericFunction, [:initialize, [:instance, :initargs], Dict()])
# Objects 
mm = Instance(MultiMethod, [[Object, Top], function (instance, initargs)
        slots, initforms = get_all_slots_and_initforms(getfield(instance, :class))
        for (slot_name, initform) in zip(slots, initforms)
            value = get(initargs, slot_name, initform)
            push!(getfield(instance, :slots), value)
        end
    end, initialize])
add_method(initialize, mm)

# Classes
mm = Instance(MultiMethod, [[Class, Top], function (instance, initargs)
        # All class slots
        call_next_method()

        # Superclasses, force Object
        direct_superclasses = getproperty(instance, DIRECT_SUPERCLASSES)
        if (direct_superclasses === missing || direct_superclasses == [])
            setproperty!(instance, DIRECT_SUPERCLASSES, [Object])
        end

        # CPL
        cpl = compute_cpl(instance)
        setproperty!(instance, CLASS_CPL, cpl)

        # Getters and setters
        all_slots = get_all_slots(instance)
        getters, setters = (Dict(), Dict())
        for i in eachindex(all_slots)
            getter, setter = compute_getter_and_setter(instance, all_slots[i], i)
            getters[all_slots[i]] = getter
            setters[all_slots[i]] = setter
        end
        set_slot(instance, GETTERS, getters)
        set_slot(instance, SETTERS, setters)

    end, initialize])
add_method(initialize, mm)

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

    add_method(generic_function, multi_method)
end

# func = new(GenericFunction, name=:func, args=[:a, :b], methods=[])


####################################################################

####################################################################
#                               MACROS                             #
####################################################################

macro defgeneric(generic_function)

    name = generic_function.args[1]
    arguments = generic_function.args[2:end]

    generic_function_name = Expr(:quote, name)

    quote
        global $name = new(GenericFunction, name=$generic_function_name, args=$arguments, methods=Dict())
    end
end

macro defmethod(method)
    name = method.args[1].args[1]
    generic_function_name = Expr(:quote, name)

    prototype = method.args[1]
    body = method.args[2]

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
            global $name = new(GenericFunction, name=$generic_function_name, args=$arguments, methods=Dict())
        end
        create_method($name, [$(specializers...),], ($(arguments...),) -> $body)
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
        elseif (typeof(slot_def) == Expr && slot_def.head == :(=))
            initform = slot_name.args[2]
            slot_name = slot_name.args[1]
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

@defclass(BuiltInClass, [Class], [])
macro defbuiltinclass(type)
    !@isdefined(type) && error("Builtin Julia type [$type] does not exist.")
    class_name = Symbol("_$type")
    esc(quote
        @defclass($class_name, [Top], [], metaclass = BuiltInClass)
        function class_of(i::$type)
            return $class_name
        end
    end)
end

### Bootstrapping Builtin
@defbuiltinclass(Int64)
@defbuiltinclass(String)


@defmethod compute_slots(class::Class) =
    vcat(map(class_direct_slots, class_cpl(class))...)


####################################################################
#                        PRE-DEFINED METHODS                       #
####################################################################

############################# Print ################################

# Objects ----------------------------------------------------------
@defmethod print_object(obj::Object, io::Top) =
    print(io, "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>")

# Classes ----------------------------------------------------------
@defmethod print_object(cls::Class, io::Top) =
    print(io, "<$(class_of(cls).name) $(cls.name)>")

# Generic Functions ------------------------------------------------
@defmethod print_object(gf::GenericFunction, io::Top) =
    print(io, "<GenericFunction $(gf.name) with $(length(gf.methods)) methods>")

# Multi Methods ----------------------------------------------------
@defmethod print_object(mm::MultiMethod, io::Top) = begin
    names = getproperty.(mm.specializers, :name)
    print(io, "<MultiMethod $(mm.generic_function.name)($(join(names, ", ")))>")
end

function Base.show(io::IO, obj::Instance)
    print_object(obj, io)
end


####################################################################
#                             Extensions                           #
####################################################################

@defclass(DylanClass, [Class], [])

@defmethod build_graph_util(class::Class, adj_list, classes) = begin
    if (!haskey(classes, class.name))
        classes[class.name] = class
    end
    for direct_superclass in class.direct_superclasses
        if (!haskey(adj_list, direct_superclass.name))
            adj_list[direct_superclass.name] = [class]
        elseif (class ∉ adj_list[direct_superclass.name])
            push!(adj_list[direct_superclass.name], class)
        end
        build_graph_util(direct_superclass, adj_list, classes)
    end
end

@defmethod build_graph(class::DylanClass) = begin
    adj_list = Dict()
    adj_list[class.name] = []

    classes = Dict()
    classes[class.name] = class

    build_graph_util(class, adj_list, classes)

    (adj_list, classes)
end

@defmethod compute_cpl(class::DylanClass) = begin

    graph, classes = build_graph(class)

    indegrees = Dict()
    for (class_name, _) in classes
        indegrees[class_name] = 0
    end

    for (class_name, adjacents) in graph
        for neighbor in adjacents
            indegrees[class_name] += 1
        end
    end

    nodes_with_no_incoming_edges = [class]
    cpl = []
    while (length(nodes_with_no_incoming_edges) > 0)
        node = pop!(nodes_with_no_incoming_edges)
        push!(cpl, node)

        for neighbor in node.direct_superclasses
            indegrees[neighbor.name] -= 1
            if indegrees[neighbor.name] == 0
                push!(nodes_with_no_incoming_edges, neighbor)
            end
        end
    end

    cpl
end



@defclass(C, [], [])
@defclass(D, [C], [])
@defclass(E, [C], [])
@defclass(F, [C, E, D], [])



## Multiple dispatch

@defclass(Shape, [], [])
@defclass(Device, [], [])
@defgeneric draw(shape, device)
@defclass(Line, [Shape], [from, to])
@defclass(Circle, [Shape], [center, radius])
@defclass(Screen, [Device], [])
@defclass(Printer, [Device], [])
@defmethod draw(shape::Line, device::Screen) = println("Drawing a Line on Screen")
@defmethod draw(shape::Circle, device::Screen) = println("Drawing a Circle on Screen")
@defmethod draw(shape::Line, device::Printer) = println("Drawing a Line on Printer")
@defmethod draw(shape::Circle, device::Printer) = println("Drawing a Circle on Printer")
let devices = [new(Screen), new(Printer)],
    shapes = [new(Line), new(Circle)]

    for device in devices
        for shape in shapes
            draw(shape, device)
        end
    end
end

# #Drawing a Line on Screen
# #Drawing a Circle on Screen
# #Drawing a Line on Printer
# #Drawing a Circle on Printer 