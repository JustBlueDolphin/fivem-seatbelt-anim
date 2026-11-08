local bound, attempt = nil, nil
local buckled = false
local function message(text)
    print('[seatbelt_anim] ' .. text)
    TriggerEvent('chat:addMessage', { args = { 'Seatbelt', text } })
end
local function context()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or not IsPedInAnyVehicle(ped, false) then return nil end
    local vehicle = GetVehiclePedIsIn(ped, false)
    local model = GetEntityModel(vehicle)
    if not Config.EnabledClasses[GetVehicleClass(vehicle)] or Config.Models[model] == false then return nil end
    local seat
    for index = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, index) == ped then seat = index; break end
    end
    if seat == nil then return nil end
    local pos = GetEntityCoords(ped)
    local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, pos.x, pos.y, pos.z)
    local settings = Config.Models[model]
    local side = type(settings) == 'table' and settings.side or (offset.x > .1 and 'right' or 'left')
    if side ~= 'left' and side ~= 'right' then side = 'left' end
    return { ped = ped, vehicle = vehicle, seat = seat, side = side }
end
local function same(a,b)
    return a and b and a.ped == b.ped and a.vehicle == b.vehicle and a.seat == b.seat
end
local function stopGesture()
    if attempt and attempt.clip and DoesEntityExist(attempt.ped) then
        StopAnimTask(attempt.ped, Config.Dictionary, attempt.clip, 4.0)
    end
    attempt = nil
end
local function restoreFlag()
    if bound and bound.savedFlag ~= nil and DoesEntityExist(bound.ped) then
        SetPedConfigFlag(bound.ped, 32, bound.savedFlag)
        bound.savedFlag = nil
    end
end
local function reset()
    stopGesture(); restoreFlag()
    if buckled then TriggerEvent('seatbelt_anim:changed', false, bound and bound.vehicle or 0) end
    bound, buckled = nil, false
end
local function sync()
    local current = context()
    if bound and not same(bound,current) then reset() end
    return current
end
local function cancel(token)
    if attempt ~= token then return end
    if same(bound,context()) then stopGesture() else reset() end
end
local function valid(token)
    return attempt == token and same(token,context()) and not IsPedRagdoll(token.ped)
        and not IsPedDoingDriveby(token.ped)
end
local function setBuckled(target)
    if type(target) ~= 'boolean' then return false, 'invalid_state' end
    local current = sync()
    if not current then return false, 'not_in_supported_vehicle' end
    if attempt then return false, 'busy' end
    if target == buckled then return true, 'unchanged' end
    if IsPedRagdoll(current.ped) or IsPedDoingDriveby(current.ped) then return false, 'ped_busy' end
    bound = bound or current
    local token = current
    token.target = target
    token.clip = (target and 'buckle_' or 'unbuckle_') .. current.side .. 'seat'
    attempt = token
    CreateThread(function()
        local start, requested = GetGameTimer(), -10000
        while not HasAnimDictLoaded(Config.Dictionary) do
            if not valid(token) then cancel(token); return end
            if GetGameTimer() - start > Config.LoadTimeoutMs then
                message('Animation dictionary failed to load. Check stream/seatbelt.ycd.')
                stopGesture(); return
            end
            if GetGameTimer() - requested >= 500 then RequestAnimDict(Config.Dictionary); requested = GetGameTimer() end
            Wait(50)
        end
        if not valid(token) then cancel(token); return end
        if GetAnimDuration(Config.Dictionary, token.clip) <= 0 then
            message('Missing clip: ' .. token.clip); stopGesture(); return
        end
        local duration = Config.Durations[target and 'buckle' or 'unbuckle']
        TaskPlayAnim(token.ped, Config.Dictionary, token.clip, 8.0, -8.0, duration, 48, 0.0, false, 2, false)
        start = GetGameTimer()
        Wait(100)
        if not valid(token) then cancel(token); return end
        if not IsEntityPlayingAnim(token.ped, Config.Dictionary, token.clip, 3) then
            message('GTA did not start the seatbelt animation; belt state unchanged.')
            stopGesture(); return
        end
        while GetGameTimer() - start < duration - 80 do
            if not valid(token) then cancel(token); return end
            if not IsEntityPlayingAnim(token.ped, Config.Dictionary, token.clip, 3) then
                message('Seatbelt animation interrupted; belt state unchanged.')
                stopGesture(); return
            end
            Wait(25)
        end
        if not valid(token) then cancel(token); return end
        if target and Config.DisableWindscreenEjection then
            bound.savedFlag = GetPedConfigFlag(token.ped, 32, true)
            SetPedConfigFlag(token.ped, 32, false)
        elseif not target then restoreFlag() end
        buckled = target
        stopGesture()
        TriggerEvent('seatbelt_anim:changed', buckled, token.vehicle)
        message(buckled and 'Seatbelt fastened.' or 'Seatbelt released.')
    end)
    return true, 'started'
end
local function toggle()
    sync()
    local ok, reason = setBuckled(not buckled)
    if not ok then message('Cannot toggle: ' .. reason) end
    return ok, reason
end
exports('Toggle', toggle)
exports('SetBuckled', setBuckled)
exports('IsBuckled', function() sync(); return buckled end)
exports('IsBusy', function() sync(); return attempt ~= nil end)
RegisterCommand(Config.Command, function(_,args)
    if args[1] == 'status' then
        sync(); message(('Buckled=%s, animating=%s'):format(tostring(buckled), tostring(attempt ~= nil)))
    elseif args[1] == 'on' or args[1] == 'off' then
        local ok, reason = setBuckled(args[1] == 'on')
        if not ok then message('Cannot toggle: ' .. reason) end
    elseif not args[1] then toggle()
    else message('/' .. Config.Command .. ' [on|off|status]') end
end, false)
RegisterKeyMapping(Config.Command, 'Fasten / release seatbelt', 'keyboard', Config.Key)
CreateThread(function()
    while true do
        sync()
        if buckled and Config.BlockExit then
            DisableControlAction(0,75,true); DisableControlAction(27,75,true)
        end
        if buckled and Config.DisableWindscreenEjection and bound then SetPedConfigFlag(bound.ped,32,false) end
        Wait((buckled or attempt) and 0 or 200)
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    reset(); RemoveAnimDict(Config.Dictionary)
end)
print('[seatbelt_anim] Loaded. Made with AI. Use /seatbelt or your mapped key.')
