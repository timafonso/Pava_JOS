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
const GENERIC_FUNCTION_SLOTS = [GENERIC_FUNCTION_NAME, GENERIC_FUNCTION_ARGS, GENERIC_FUNCTION_METHODS]

const MM_SPECIALIZERS = :specializers
const MM_QUALIFIER = :qualifier
const MM_PROCEDURE = :procedure
const MM_GENERIC_FUNCTION = :generic_function
const MM_SLOTS = [MM_SPECIALIZERS, MM_QUALIFIER, MM_PROCEDURE, MM_GENERIC_FUNCTION]
const MM_QUALIFIER_BEFORE = :before
const MM_QUALIFIER_PRIMARY = :primary
const MM_QUALIFIER_AFTER = :after

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

MultiMethod = Instance(Class, [MM_SLOTS, :MultiMethod, [Object]])
push!(MultiMethod.slots, [MultiMethod, Object, Top])    #cpl
push!(MultiMethod.slots, [missing, missing, missing, missing])   #initforms
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
    getproperty(instance, MM_SPECIALIZERS)
end

# ------------------------------------------------------------------
function add_method(generic_function, multi_method)
    key = (map(x -> x.name, multi_method.specializers)..., getproperty(multi_method, MM_QUALIFIER))
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
_bootstrap_class_getters_and_setters(MultiMethod, MM_SLOTS)

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

    # before
    before_methods = filter((x) -> getproperty(x, MM_QUALIFIER) == MM_QUALIFIER_BEFORE, best_methods)
    for method in before_methods
        method.procedure(args...)
    end

    # primary
    primary_methods = filter((x) -> getproperty(x, MM_QUALIFIER) == MM_QUALIFIER_PRIMARY, best_methods)
    applicable_method_stack_backup = applicable_method_stack
    global applicable_method_stack = MethodCallStack(primary_methods, args, generic_f)
    result = call_next_method()
    global applicable_method_stack = applicable_method_stack_backup

    # after
    after_methods = filter((x) -> getproperty(x, MM_QUALIFIER) == MM_QUALIFIER_AFTER, best_methods)
    for method in before_methods
        method.procedure(args...)
    end

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
mm = Instance(MultiMethod, [[Object], MM_QUALIFIER_PRIMARY, (obj) -> (Instance(obj)), allocate_instance])
add_method(allocate_instance, mm)
# Classes 
mm = Instance(MultiMethod, [[Class], MM_QUALIFIER_PRIMARY, (cls) -> (Instance(cls)), allocate_instance])
add_method(allocate_instance, mm)

# COMPUTE GETTERS AND SETTERS -------------------------------------------------------
compute_getter_and_setter = Instance(GenericFunction, [:compute_getter_and_setter, [:class, :slot, :idx], Dict()])
# Class 
mm = Instance(MultiMethod, [[Class, Top, Top], MM_QUALIFIER_PRIMARY, function (class, slot, idx)
        getter = (inst) -> (getfield(inst, :slots)[idx])
        setter = (inst, v) -> (getfield(inst, :slots)[idx] = v)
        return (getter, setter)
    end, compute_getter_and_setter])
add_method(compute_getter_and_setter, mm)

# COMPUTE Slots -------------------------------------------------------
compute_slots = Instance(GenericFunction, [:compute_slots, [:class], Dict()])
# Class 
mm = Instance(MultiMethod, [[Class], MM_QUALIFIER_PRIMARY, function (class)
        vcat(map(class_direct_slots, class_cpl(class))...)
    end, compute_slots])
add_method(compute_slots, mm)

# INITIALIZE -------------------------------------------------------
initialize = Instance(GenericFunction, [:initialize, [:instance, :initargs], Dict()])
# Objects 
mm = Instance(MultiMethod, [[Object, Top], MM_QUALIFIER_PRIMARY, function (instance, initargs)
        slots, initforms = get_all_slots_and_initforms(getfield(instance, :class))
        for (slot_name, initform) in zip(slots, initforms)
            value = get(initargs, slot_name, initform)
            push!(getfield(instance, :slots), value)
        end
    end, initialize])
add_method(initialize, mm)

# Classes
mm = Instance(MultiMethod, [[Class, Top], MM_QUALIFIER_PRIMARY, function (instance, initargs)
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
function create_method(generic_function, specializers, procedure, qualifier=MM_QUALIFIER_PRIMARY)
    (length(generic_function.args) == length(specializers)) || error("Wrong specializers for generic function.")

    multi_method = new(MultiMethod, specializers=specializers, qualifier=qualifier, procedure=procedure, generic_function=generic_function)

    add_method(generic_function, multi_method)
end

# func = new(GenericFunction, name=:func, args=[:a, :b], methods=[])


####################################################################

####################################################################
#                        PRE-DEFINED METHODS                       #
####################################################################

############################# Print ################################

global print_object = new(GenericFunction, name=:print_object, args=[:obj, :io], methods=Dict())

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

macro defmethod(qualifier, method)
    name = method.args[1].args[1]
    generic_function_name = Expr(:quote, name)
    qualifier = Expr(:quote, qualifier)

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
        create_method($name, [$(specializers...),], ($(arguments...),) -> $body, $qualifier)
    end
end

macro defmethod(method)
    quote
        @defmethod primary $method
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

####################################################################
#                               TESTING                            #
####################################################################

## Testing method combination

@defclass(Foo, [], [a = 1])

@defmethod before bar(c::Foo) = display("before")
@defmethod bar(c::Foo) = display("primary")
@defmethod after bar(c::Foo) = display("after")

f = new(Foo)
bar(f)


# @defmethod compute_slots(class::Class) =
#     vcat(map(class_direct_slots, class_cpl(class))...)


# @defclass(Foo, [], [[a = 1], [b = 2]])
# @defclass(Bar, [], [[b = 3], [c = 4]])
# @defclass(FooBar, [Foo, Bar], [[a = 5], [d = 6]])
# @defclass(AvoidCollisionsClass, [Class], [])

# @defmethod compute_slots(class::AvoidCollisionsClass) =
#     let slots = call_next_method(),
#         duplicates = symdiff(slots, unique(slots))

#         isempty(duplicates) ?
#         slots :
#         error("Multiple occurrences of slots: $(join(map(string, duplicates), ", "))")
#     end

# # @defclass(FooBar2, [Foo, Bar], [[a = 5], [d = 6]], metaclass = AvoidCollisionsClass)

# #--------------------------------------------------------------------------

# undo_trail = []
# store_previous(object, slot, value) = push!(undo_trail, (object, slot, value))
# current_state() = length(undo_trail)
# restore_state(state) =
#     while length(undo_trail) != state
#         restore(pop!(undo_trail)...)
#     end
# save_previous_value = true
# restore(object, slot, value) =
#     let previous_save_previous_value = save_previous_value
#         global save_previous_value = false
#         try
#             setproperty!(object, slot, value)
#         finally
#             global save_previous_value = previous_save_previous_value
#         end
#     end

# @defclass(UndoableClass, [Class], [])

# @defmethod compute_getter_and_setter(class::UndoableClass, slot, idx) =
#     let (getter, setter) = call_next_method()
#         (getter,
#             (o, v) -> begin
#                 if save_previous_value
#                     store_previous(o, slot, getter(o))
#                 end
#                 setter(o, v)
#             end)
#     end

# @defclass(Person, [],
#     [name, age, friend],
#     metaclass = UndoableClass)
# @defmethod print_object(p::Person, io) =
#     print(io, "[$(p.name), $(p.age)$(ismissing(p.friend) ? "" : " with friend $(p.friend)")]")

# p0 = new(Person, name="John", age=21)
# p1 = new(Person, name="Paul", age=23)
# #Paul has a friend named John
# p1.friend = p0
# println(p1) #[Paul,23 with friend [John,21]]
# state0 = current_state()
# #32 years later, John changed his name to 'Louis' and got a friend
# p0.age = 53
# p1.age = 55
# p0.name = "Louis"
# p0.friend = new(Person, name="Mary", age=19)
# println(p1) #[Paul,55 with friend [Louis,53 with friend [Mary,19]]]
# state1 = current_state()
# #15 years later, John (hum, I mean 'Louis') died
# p1.age = 70
# p1.friend = missing
# println(p1) #[Paul,70]
# #Let's go back in time
# restore_state(state1)
# println(p1) #[Paul,55 with friend [Louis,53 with friend [Mary,19]]]
# #and even earlier
# restore_state(state0)
# println(p1) #[Paul,23 with friend [John,21]]

# #--------------------------------------------------------------------------

# @defclass(CountingClass, [Class], [counter = 0])

# @defmethod allocate_instance(class::CountingClass) = begin
#     class.counter += 1
#     call_next_method()
# end

# #--------------------------------------------------------------------------

# # @defclass(UndoableCountingClass,
# #     [UndoableClass, CountingClass],
# #     [])

# # @defclass(UCerson, [],
# #     [name, age, friend],
# #     metaclass = UndoableCountingClass)

# # p0 = new(UCPerson, name="John", age=21)

# #--------------------------------------------------------------------------


# @defclass(UndoableCollisionAvoidingCountingClass,
#     [UndoableClass, AvoidCollisionsClass, CountingClass],
#     [])
# @defclass(NamedThing, [], [name])
# # @defclass(Person, [NamedThing],
# #     [name, age, friend],
# #     metaclass = UndoableCollisionAvoidingCountingClass)
# @defclass(Person, [NamedThing],
#     [age, friend],
#     metaclass = UndoableCollisionAvoidingCountingClass)
# @defmethod print_object(p::Person, io) =
#     print(io, "[$(p.name), $(p.age)$(ismissing(p.friend) ? "" : " with friend $(p.friend)")]")

# p0 = new(Person, name="John", age=21)
# p1 = new(Person, name="Paul", age=23)
# #Paul has a friend named John
# p1.friend = p0
# println(p1) #[Paul,23 with friend [John,21]]
# state0 = current_state()
# #32 years later, John changed his name to 'Louis' and got a friend
# p0.age = 53
# p1.age = 55
# p0.name = "Louis"
# p0.friend = new(Person, name="Mary", age=19)
# println(p1) #[Paul,55 with friend [Louis,53 with friend [Mary,19]]]
# state1 = current_state()
# #15 years later, John (hum, I mean 'Louis') died
# p1.age = 70
# p1.friend = missing
# println(p1) #[Paul,70]
# #Let's go back in time
# restore_state(state1)
# println(p1) #[Paul,55 with friend [Louis,53 with friend [Mary,19]]]
# #and even earlier
# restore_state(state0)
# println(p1) #[Paul,23 with friend [John,21]]

# Person.counter


# class_of(1)
# class_of("Foo")

# @defmethod add(a::_Int64, b::_Int64) = a + b
# @defmethod add(a::_String, b::_String) = a * b

# add(1, 3)
# add("Foo", "Bar")
#--------------------------------------------------------------------------

# @defclass(ComplexNumber, [], [real, imag])
# c = new(ComplexNumber, real=1, imag=1)

# @defmethod add(a::ComplexNumber, b::ComplexNumber) =
#     new(ComplexNumber, real=(a.real + b.real), imag=(a.imag + b.imag))

# @defclass(MoreComplexNumber, [ComplexNumber], [morereal])
# mc = new(MoreComplexNumber, morereal=44, real=1, imag=1)

# @defclass(CountingClass, [Class], [[counter = 0]])

# @defmethod allocate_instance(class::CountingClass) = begin
#     class.counter += 1
#     call_next_method()
# end

#@defclass(CountablePerson, [], [age], metaclass = CountingClass)

#cp = new(CountablePerson, age=1)

# show("end")


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

# @defclass(Shape, [], [])
# @defclass(Device, [], [])
# @defgeneric draw(shape, device)
# @defclass(Line, [Shape], [from, to])
# @defclass(Circle, [Shape], [center, radius])
# @defclass(Screen, [Device], [])
# @defclass(Printer, [Device], [])
# @defmethod draw(shape::Line, device::Screen) = println("Drawing a Line on Screen")
# @defmethod draw(shape::Circle, device::Screen) = println("Drawing a Circle on Screen")
# @defmethod draw(shape::Line, device::Printer) = println("Drawing a Line on Printer")
# @defmethod draw(shape::Circle, device::Printer) = println("Drawing a Circle on Printer")
# let devices = [new(Screen), new(Printer)],
#     shapes = [new(Line), new(Circle)]

#     for device in devices
#         for shape in shapes
#             draw(shape, device)
#         end
#     end
# end

# #Drawing a Line on Screen
# #Drawing a Circle on Screen
# #Drawing a Line on Printer
# #Drawing a Circle on Printer 
