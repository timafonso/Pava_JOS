
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