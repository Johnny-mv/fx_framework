FX = {}

exports("getCore", function()
    return FX
end)

exports("setCore", function(core)
    FX = core
end)

exports("getParam", function(paramName)
    return FX.Params[paramName]
end)

exports("setParam", function(paramName, value)
    FX.Params[paramName] = value
end)