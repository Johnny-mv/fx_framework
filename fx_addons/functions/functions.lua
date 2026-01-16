-- Framework --
FX = FX or {}

local xSound = exports.xsound

local cars = {}
local players = {}
local peds = {}
local objects = {}
local blips = {}
local markers = {}
local bans = {}

-- [[ Server ]] --
function FX:GetPlayer(src)
    local xPlayer = ESX.GetPlayerFromId(src)

    if (xPlayer) then
        return xPlayer
    end

    return nil
end

function FX:GetIdentifier(id)
    if (IsDuplicityVersion()) then
        return Player(id).state['identifier']
    end
    return Player(id or GetPlayerServerId(PlayerId())).state['identifier']
end

function FX:KickPlayer(id, reason)
    DropPlayer(id, reason)
    FX:SendDebug(false, string.format("%s » %s", "Kick", "Spieler mit der ID " .. id .. " wurde gekickt. Grund: " .. reason))
end 

function FX:RegisterCommand(command, perms, callback, console)
    if (console == nil) then
        console = true
    end
    local _perms = perms
    RegisterCommand(command, function(source, args)
        if (source == 0 and console == true) then
            callback(source, args)
            return;
        end
        if (source == 0 and console == false) then
            FX:SendDebug(false,
                string.format("%s » %s", "Command", "Dieser Command kann nur Ingame ausgeführt werden."))
            return;
        end
        local xPlayer = FX:GetPlayer(source)
        if (#_perms == nil) or (_perms[xPlayer.getGroup()] == true) then
            callback(source, args)
            return;
        else
            FX:SendDebug(false, string.format("%s » %s", "Command", "Du hast keine Berechtigung für diesen Befehl."))
            return;
        end
    end, false)
end

function FX:GetArray(array, key)
    if not array or type(array) ~= "table" then
        return "Keine Daten verfügbar"
    end

    if key then
        return array[key] or "Nicht verfügbar"
    end
end

function FX:ifAnd(key, value, default)
    if key and value then
        return value
    end

    return default
end

function FX:GetItem(src, item, count)
    local xPlayer = FX:GetPlayer(src)

    if (xPlayer) then
        local xItem = xPlayer.getInventoryItem(item)
        local xCount = xItem.count

        if xCount >= count then
            return xItem
        end
    end

    return nil
end

function FX:AddItem(src, item, count)
    local xPlayer = FX:GetPlayer(src)

    if (xPlayer) then
        if xPlayer.canCarryItem(item, count) then
            xPlayer.addInventoryItem(item, count)
            return true
        else
            FX:SendDebug(false, string.format("%s » %s", "Inventory", "Du kannst nicht mehr Items tragen"))
            return false
        end
    end

    return false
end

function FX:RemoveItem(src, item, count)
    local xPlayer = FX:GetPlayer(src)

    if (xPlayer) then
        local xItem = xPlayer.getInventoryItem(item)
        local xCount = xItem.count

        if xCount >= count then
            xPlayer.removeInventoryItem(item, count)
            return true
        else
            return false
        end
    end

    return false
end

function FX:RemoveWeapon(src, weapon)
    local xPlayer = FX:GetPlayer(src)

    if (xPlayer) then
        if xPlayer.hasWeapon(weapon) then
            xPlayer.removeWeapon(weapon)
            return true
        else
            return false
        end
    end

    return false
end

function FX:AddWeapon(src, weapon, ammo)
    local xPlayer = FX:GetPlayer(src)

    if (xPlayer) then
        if not xPlayer.hasWeapon(weapon) then
            xPlayer.addWeapon(weapon, ammo)
            return true
        else
            return false
        end
    end

    return false
end

function FX:CanPayServer(method, source, amount)
    local xPlayer = FX:GetPlayer(source)

    if (xPlayer) then
        if method == 'card' then
            return xPlayer.getAccount('bank').money >= amount
        elseif method == 'black' then
            return xPlayer.getAccount('black_money').money >= amount
        else
            return xPlayer.getMoney() >= amount
        end
    end

    return false
end

function FX:PayServer(method, source, amount)
    local xPlayer = FX:GetPlayer(source)

    if (xPlayer) then
        if method == 'card' then
            xPlayer.removeAccountMoney('bank', amount)
        elseif method == 'black' then
            xPlayer.removeAccountMoney('black_money', amount)
        else
            xPlayer.removeMoney(amount)
        end
    end
end

function FX:GetNumJobPlayers(jobs)
    local count = 0

    for _, xTarget in ipairs(ESX.GetExtendedPlayers()) do
        for _, job in ipairs(jobs) do
            if xTarget.getJob().name == job then
                count = count + 1
            end
        end
    end

    return count
end

-- Vehicle --
local function DoesPlateExist(plate)
    local status = promise:new()

    Query("SELECT plate FROM owned_vehicles WHERE plate = @plate", {
        ["@plate"] = plate
    }, function(result)
        status:resolve(result[1] ~= nil)
    end)

    Citizen.Await(status)

    return status.value
end

local function GenerateRandomPlate()
    local letters = ""
    local numbers = ""
    for i = 1, 3 do
        letters = letters .. string.char(math.random(65, 90))
    end
    for i = 1, 3 do
        numbers = numbers .. tostring(math.random(0, 9))
    end
    return letters .. " " .. numbers
end

local function GeneratePlate(input)
    if not input or input:match("^%s*$") then
        return GenerateRandomPlate()
    else
        input = string.upper(input)
        input = input:match("^%s*(.-)%s*$")
    end

    local letters, numbers = input:match("^(%a%a%a)%s*(%d%d%d)$")
    if letters and numbers then
        return letters .. " " .. numbers
    else
        return nil
    end
end

function FX:GiftVehicle(identifier, props, type, fcb)
    local plate = GeneratePlate()

    Query(
        "INSERT INTO owned_vehicles (owner, plate, type, stored, vehicle) VALUES (@owner, @plate, @type, @stored, @vehicle)",
        {
            ['@owner'] = identifier,
            ['@plate'] = plate,
            ["@stored"] = 0,
            ["@type"] = type,
            ['@vehicle'] = json.encode(props)
        }, function(result)
            if result then
                fcb(true)
            end
        end)
end

-- Vehicle --

-- [[ Client ]] --
function FX:RegisterKey(command, desc, key)
    RegisterKeyMapping(command, desc, 'keyboard', key)
end

function FX:HaveItem(item, count)
    for k, v in pairs(ESX.GetPlayerData().inventory) do
        if v.name == item then
            if v.count >= count then
                return true
            end
        end
    end

    return false
end

function FX:HaveMoney(money)
    for k, v in pairs(ESX.GetPlayerData().accounts) do
        if v.name == 'money' then
            if v.money >= money then
                return true
            end
        elseif v.name == 'bank' then
            if v.money >= money then
                return true
            end
        end
    end

    return false
end

function FX:GetMoney(type, format)
    for k, v in pairs(ESX.GetPlayerData().accounts) do
        if v.name == type then
            if format then
                return ESX.Math.GroupDigits(v.money)
            else
                return v.money
            end
        end
    end
end

function FX:TimeToStart(enabled, start, stop)
    local hour = tonumber(GetClockHours())

    if hour then
        if enabled then
            if hour >= start and hour < stop then
                return true
            else
                return false
            end
        else
            return true
        end
    else
        return false
    end
end

function FX:GetPlaytime(playerData)
    if not playerData or not playerData.metadata or not playerData.metadata.lastPlaytime then
        return "0h 0m"
    end

    local seconds = playerData.metadata.lastPlaytime
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%dh %dm", hours, minutes)
end

function FX:CreatePed(model, pos, heading, networked, cb)
    if (model) then
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(0)
        end
    end

    local ped = CreatePed(0, model, pos.x, pos.y, pos.z - 1, heading, networked, false)
    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if cb then
        cb(ped)
    end

    return ped
end

function FX:Blip(pos, data)
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)

    SetBlipSprite(blip, data.sprite)
    SetBlipDisplay(blip, data.display)
    SetBlipScale(blip, data.scale)
    SetBlipColour(blip, data.color)
    SetBlipAsShortRange(blip, data.shortrange)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString((data and data.name) and data.name or data.name)
    EndTextCommandSetBlipName(blip)

    return blip
end

function FX:DrawText3D(pos, text, r, g, b)
    local onScreen, x, y = World3dToScreen2d(pos.x, pos.y, pos.z)
    local dist = #(GetGameplayCamCoords() - pos)

    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov

    if (onScreen) then
        SetTextScale(0.0, 0.45 * scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(r, g, b, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(x, y)
    end
end

function FX:DrawTextOnScreen(text, scale, color, pos)
    SetTextCentre(true)
    SetTextProportional(1)
    SetTextFont(4)
    SetTextScale(scale.x, scale.y)
    SetTextColour(color.r, color.g, color.b, color.a)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(pos.x, pos.y)
end

function FX:Marker(data)
    local scaleX = data.scale
    local scaleY = data.scale
    local scaleZ = data.scale

    if (type(data.scale) == 'vector3') then
        scaleX = data.scale.x
        scaleY = data.scale.y
        scaleZ = data.scale.z
    end

    local marker = DrawMarker(data.type, data.pos.x, data.pos.y, data.pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scaleX,
        scaleY,
        scaleZ, data.red, data.green, data.blue, data.alpha, data.upanddown, data.faceplayer, 2, data.rotate, false,
        false, false)

    return marker
end

function FX:PlaySound(ped, url, volume, coords, radius)
    local isPlaying = false
    if (not isPlaying) then
        isPlaying = true
        local soundName = "sound_" .. tostring(ped)
        xSound:PlayUrlPos(soundName, url, volume, coords, true)
        xSound:Distance(soundName, radius)
    end
end

function FX:PlayAnim(dict, anim, time, callback)
    ESX.Streaming.RequestAnimDict(dict, function()
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, time, 0, 0, false, false, false)

            CreateThread(function()
                Wait(time)

                if callback then
                    callback()
                end
            end)
        end
    end)
end

function FX:AttachProp(prop, bone, rotation)
    local ped = ESX.PlayerData.ped
    local x, y, z = table.unpack(GetEntityCoords(ped))
    prop = CreateObject(GetHashKey(prop), x, y, z + 0.2, true, true, true)
    local bone = bone or 57005
    local boneIndex = GetPedBoneIndex(ped, bone)
    AttachEntityToEntity(prop, ped, boneIndex, 0.12, 0.028, 0.001, 10.0, rotation or 90.0, 0.0, true, true, false, true,
        1, true)

    return prop
end

function FX:CreateObj(prop, coords, heading, freeze, networked)
    networked = networked == nil and true or networked

    local model = type(prop) == "number" and prop or joaat(prop)
    local vector = type(coords) == "vector3" and coords or vec(coords.x, coords.y, coords.z)

    if not vector then
        FX:SendDebug(false, "Invalid coordinates provided to CreateObj")
        return nil
    end

    ESX.Streaming.RequestModel(model)

    local object = CreateObject(model, vector.xyz, networked, false, true)

    if DoesEntityExist(object) then
        SetEntityAsMissionEntity(object, true, true)
        SetEntityHeading(object, heading)
        PlaceObjectOnGroundOrObjectProperly(object)
        FreezeEntityPosition(object, freeze)

        return object
    else
        FX:SendDebug(false, "» [ERROR] " .. prop .. " konnte nicht erstellt werden!")
        return nil
    end
end

function FX:CreateLocalObj(prop, coords, heading, freeze)
    return FX:CreateObj(prop, coords, heading, freeze, false)
end

function FX:PlayPropAnim(prop, bone, rotation, position, dict, anim)
    if (not prop) then
        return print("No prop")
    end

    if (not bone) then
        return print("No bone")
    end

    if (not dict) then
        return print("No dict")
    end

    if (not anim) then
        return print("No anim")
    end

    local ped = PlayerPedId()
    local x, y, z = table.unpack(GetEntityCoords(ped))
    local _prop = CreateObject(GetHashKey(prop), x, y, z, true, true, true)
    local boneIndex = GetPedBoneIndex(ped, bone)
    local rot = rotation or { 0.0, 0.0, 0.0 }
    local pos = position or { 0.0, 0.0, 0.0 }
    AttachEntityToEntity(_prop, ped, boneIndex, pos[1], pos[2], pos[3], rot[1], rot[2], rot[3], true,
        true, false, true, 1, true)
    SetEntityAsNoLongerNeeded(_prop)

    ESX.Streaming.RequestAnimDict(dict, function()
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, anim, 16.0, 16.0, -1, 1 or 1, 0, false,
                false, false)
            Wait(500)
            FreezeEntityPosition(ped, true)
        end
    end)

    return _prop
end

if not IsDuplicityVersion() then
    function FX:IsBlacklisted(job, table)
        for _, v in pairs(table) do
            if v == job then
                return true
            end
        end

        return false
    end
else
    function FX:IsBlacklisted(src, job, table)
        local xPlayer = FX:GetPlayer(src)

        for _, v in pairs(table) do
            if v == xPlayer.job.name then
                return true
            end
        end

        return false
    end
end

function FX:IsSombebodyNear()
    local pedId, distance = ESX.Game.GetClosestPlayer()

    if pedId ~= -1 and distance < 3.0 then
        return true, pedId
    else
        return false
    end
end

function FX:MinSeconds(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

function FX:FullTuneCar(vehicle)
    SetVehicleModKit(vehicle, 0)
    SetVehicleWheelType(vehicle, 7)

    for i = 0, 16 do
        local maxMod = GetNumVehicleMods(vehicle, i)
        if maxMod > 0 then
            SetVehicleMod(vehicle, i, maxMod - 1, false)
        end
    end

    ToggleVehicleMod(vehicle, 17, true)
    ToggleVehicleMod(vehicle, 18, true)
    ToggleVehicleMod(vehicle, 19, true)
    ToggleVehicleMod(vehicle, 20, true)
    ToggleVehicleMod(vehicle, 21, true)
    ToggleVehicleMod(vehicle, 22, true)

    if GetNumVehicleMods(vehicle, 25) > 0 then SetVehicleMod(vehicle, 25, GetNumVehicleMods(vehicle, 25) - 1, false) end
    if GetNumVehicleMods(vehicle, 27) > 0 then SetVehicleMod(vehicle, 27, GetNumVehicleMods(vehicle, 27) - 1, false) end
    if GetNumVehicleMods(vehicle, 28) > 0 then SetVehicleMod(vehicle, 28, GetNumVehicleMods(vehicle, 28) - 1, false) end
    if GetNumVehicleMods(vehicle, 30) > 0 then SetVehicleMod(vehicle, 30, GetNumVehicleMods(vehicle, 30) - 1, false) end
    if GetNumVehicleMods(vehicle, 33) > 0 then SetVehicleMod(vehicle, 33, GetNumVehicleMods(vehicle, 33) - 1, false) end
    if GetNumVehicleMods(vehicle, 34) > 0 then SetVehicleMod(vehicle, 34, GetNumVehicleMods(vehicle, 34) - 1, false) end
    if GetNumVehicleMods(vehicle, 35) > 0 then SetVehicleMod(vehicle, 35, GetNumVehicleMods(vehicle, 35) - 1, false) end
    if GetNumVehicleMods(vehicle, 38) > 0 then SetVehicleMod(vehicle, 38, GetNumVehicleMods(vehicle, 38) - 1, true) end

    SetVehicleWindowTint(vehicle, 1)
    SetVehicleTyresCanBurst(vehicle, false)
    SetVehicleNumberPlateTextIndex(vehicle, 5)
end

function FX:State(state, hud)
    DisplayRadar(state)
    -- exports["FX_hud"]:Status(hud)
end

function FX:ShowNotification(message)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(false, false)
end

function FX:SendDebug(json, message)
    if json then
        print(json.encode("[^2FX^7] " .. message, { indent = true }))
    else
        print("[^2FX^7] " .. message)
    end
end

-- Framework --

-- HUD --
function FX:Announce(clients, header, message, time)
    TriggerClientEvent('FX_hud:announce', clients, header, message, time)
end

function FX:Progressbar(title, time)
    TriggerEvent("FX_hud:progressbar", title or "Ladevorgang..", time)
end

function FX:ProgressbarCancel()
    TriggerEvent("FX_hud:HideProgressbar")
end

function FX:HelpNotify(key, message)
    TriggerEvent("FX_hud:helpnotify", key, message)
end

function FX:hide(state)
    TriggerEvent("FX_hud:Request", state)
end

function FX:Request(data, cb)
    TriggerEvent("FX_hud:Request", data, cb)
end

if not IsDuplicityVersion() then
    function FX:Notify(type, title, message, time)
        TriggerEvent("utoria_hud:notify", type, title, message, time)
    end
else
    function FX:Notify(src, type, title, message, time)
        TriggerClientEvent("utoria_hud:notify", src, type, title or "Information", message, time or 5000)
    end
end
-- HUD --
