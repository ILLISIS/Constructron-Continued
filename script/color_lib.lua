local me = {}

me.colors = {}
me.colors.red = {
    r = 1,
    g = 0,
    b = 0
}
me.colors.green = {
    r = 0,
    g = 0.65,
    b = 0
}
me.colors.blue = {
    r = 0,
    g = 0.35,
    b = 0.65
}
me.colors.pink = {
    r = 0,
    g = 0.65,
    b = 0.65
}
me.colors.white = {
    r = 0.65,
    g = 0.65,
    b = 0.65
}

me.color_alpha = function(color, alpha)
    color.a = alpha
    return color
end

return me
