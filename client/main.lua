-- client/main.lua
local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    print("^2[qb-vehicle] client/main.lua loaded (optimized build)^7")
end)

-- ===== Helpers & State =====
local function Notify(msg, typ)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, typ or 'primary')
    else
        TriggerEvent('QBCore:Notify', msg, typ or 'primary')
        print(("[%s] %s"):format(typ or "info", msg))
    end
end

local function PlayerPed() return PlayerPedId() end
local function PlayerInVehicle() return IsPedInAnyVehicle(PlayerPed(), false) end
local function GetPlayerVehicle()
    local p = PlayerPed()
    if IsPedInAnyVehicle(p,false) then return GetVehiclePedIsIn(p,false) end
    return 0
end

local nuiOpen = false
local currentContext = nil -- 'outside' | 'inside'
local cachedVeh = nil
local seatbeltOn = false

-- ===== Vehicle control functions =====
local function ToggleEngine()
    -- central event de facto i många servers
    TriggerEvent('qb-vehiclekeys:client:ToggleEngine')
end

local function ToggleLock(veh)
    if not veh or veh == 0 then return end
    local lock = GetVehicleDoorLockStatus(veh)
    if lock == 1 or lock == 0 then
        SetVehicleDoorsLocked(veh, 2)
        PlayVehicleDoorCloseSound(veh, 1)
        Notify('Fordon låst', 'success')
    else
        SetVehicleDoorsLocked(veh, 1)
        PlayVehicleDoorOpenSound(veh, 0)
        Notify('Fordon upplåst', 'success')
    end
end

local function ToggleDoor(veh, doorIndex)
    if not veh or veh == 0 then return end
    if GetVehicleDoorAngleRatio(veh, doorIndex) > 0.1 then
        SetVehicleDoorShut(veh, doorIndex, false)
    else
        SetVehicleDoorOpen(veh, doorIndex, false, false)
    end
end

local function ToggleWindow(veh, windowIndex)
    if not veh or veh == 0 then return end
    if IsVehicleWindowIntact(veh, windowIndex) then
        if not Entity(veh).state['win'..windowIndex] then
            RollDownWindow(veh, windowIndex)
            Entity(veh).state['win'..windowIndex] = true
        else
            RollUpWindow(veh, windowIndex)
            Entity(veh).state['win'..windowIndex] = nil
        end
    else
        FixVehicleWindow(veh, windowIndex)
        RollUpWindow(veh, windowIndex)
        Entity(veh).state['win'..windowIndex] = nil
    end
end

local function ToggleSeatbelt()
    local ped = PlayerPed()
    if not IsPedInAnyVehicle(ped, false) then
        Notify('Du sitter inte i ett fordon', 'error')
        return
    end
    seatbeltOn = not seatbeltOn
    TriggerEvent('InteractSound_CL:PlayOnOne', 'seatbelt', 0.2)
    if seatbeltOn then Notify('Säkerhetsbälte: PÅ', 'success') else Notify('Säkerhetsbälte: AV', 'error') end
end

-- Blockera utgång när bälte på (sov smart)
CreateThread(function()
    while true do
        if seatbeltOn then
            DisableControlAction(0, 75, true)
            DisableControlAction(27, 75, true)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- ===== NUI open/close =====
local function SetOpen(open)
    if nuiOpen == open then return end
    nuiOpen = open
    SetNuiFocus(open, open)
    SetNuiFocusKeepInput(open)

    -- synka UI-panelens synlighet
    SendNUIMessage({
        response = open and 'openTarget' or 'closeTarget'
    })
end

local function closeAllNui()
    -- Stäng ev. meny i UI:t först
    SendNUIMessage({ response = 'closeMenu' })

    -- Stäng panel/fokus
    SetOpen(false)
    currentContext = nil
    cachedVeh = nil
end

-- ===== ALT-hold enforcement for "outside" =====
local function EnforceAltHoldOutside()
    -- Kör bara för outside, och bara medan UI är öppet
    CreateThread(function()
        while nuiOpen and currentContext == 'outside' do
            -- 19 = LEFT ALT
            if not IsControlPressed(0, 19) then
                closeAllNui()
                break
            end
            Wait(0)
        end
    end)
end

-- ===== Submenyer (showMenu-UI) =====
ShowDoorsMenu = function()
    if not cachedVeh or cachedVeh == 0 then return end
    local opts = {}
    for _, d in ipairs(Config.DoorList) do
        opts[#opts+1] = { id = ('door:%d'):format(d.id), label = d.label, icon = Config.Icons.Doors }
    end
    opts[#opts+1] = { id = 'back', label = 'Tillbaka', icon = Config.Icons.Back }

    SendNUIMessage({
        response = 'showMenu',
        data = { id = 'doors', title = 'Dörrar', hint = 'Vänsterklick för att välja • Högerklick för att stänga', options = opts }
    })
end

ShowWindowsMenu = function()
    if not cachedVeh or cachedVeh == 0 then return end
    local opts = {}
    for _, w in ipairs(Config.WindowList) do
        opts[#opts+1] = { id = ('window:%d'):format(w.id), label = w.label, icon = Config.Icons.Windows }
    end
    opts[#opts+1] = { id = 'back', label = 'Tillbaka', icon = Config.Icons.Back }

    SendNUIMessage({
        response = 'showMenu',
        data = { id = 'windows', title = 'Fönster', hint = 'Vänsterklick för att välja • Högerklick för att stänga', options = opts }
    })
end

-- ===== Menyer (target-läge för root) =====
OpenInsideMenu = function(veh)
    currentContext = 'inside'
    cachedVeh = veh
    local engineOn = GetIsVehicleEngineRunning(veh)
    local options = {
        [1] = { label = 'Säkerhetsbälte', icon = Config.Icons.Seatbelt, state = seatbeltOn and 'På' or 'Av' },
        [2] = { label = 'Motor',         icon = Config.Icons.Doors,   state = (engineOn and 'På' or 'Av') },
        [3] = { label = 'Lås/Lås upp',   icon = Config.Icons.Locks },
        [4] = { label = 'Dörrar',        icon = Config.Icons.Doors },
        [5] = { label = 'Fönster',       icon = Config.Icons.Windows },
    }
    SetOpen(true)
    SendNUIMessage({
        response = 'validTarget', -- OK: vi kör root som "target"-lista (din UX)
        data = options,
        meta = { title = 'Fordon (inuti)', hint = 'Håll ALT • Släpp för att stänga' }
    })
end

OpenOutsideDoors = function(entity)
    currentContext = 'outside'
    cachedVeh = entity
    SetOpen(true)
    ShowDoorsMenu()
    EnforceAltHoldOutside() -- håll ALT för att behålla öppen
end

OpenOutsideMenu = function(entity)
    currentContext = 'outside'
    cachedVeh = entity
    local options = {
        [1] = { label = 'Lås/Lås upp', icon = Config.Icons.Locks },
        [2] = { label = 'Dörrar',      icon = Config.Icons.Doors },
    }
    SetOpen(true)
    SendNUIMessage({
        response = 'validTarget',
        data = options,
        meta = { title = 'Fordon (utanför)', hint = 'Håll ALT • Släpp för att stänga' }
    })
    EnforceAltHoldOutside() -- håll ALT för att behålla öppen
end

-- qb-target utanför (kräv ALT för konsekvent UX)
CreateThread(function()
    exports['qb-target']:AddGlobalVehicle({
        options = {
            {
                icon = 'fas fa-lock',
                label = 'Lås/Lås upp',
                distance = Config.TargetVehicleDistance,
                action = function(entity)
                    if PlayerInVehicle() then return end
                    if not IsControlPressed(0, 19) then
                        Notify('Håll ALT för fordonsmeny', 'error')
                        return
                    end
                    ToggleLock(entity)
                end
            },
            {
                icon = 'fas fa-car-side',
                label = 'Dörrar',
                distance = Config.TargetVehicleDistance,
                action = function(entity)
                    if PlayerInVehicle() then return end
                    if not IsControlPressed(0, 19) then
                        Notify('Håll ALT för fordonsmeny', 'error')
                        return
                    end
                    OpenOutsideDoors(entity) -- öppnar + stänger när ALT släpps
                end
            },
        }
    })
end)

-- ALT hold: öppna/stäng inuti + stäng om ALT släpps (en sammanhållen loop)
CreateThread(function()
    local wasPressed = false
    while true do
        local sleep = 80
        if PlayerInVehicle() then
            local pressed = IsControlPressed(0, 19) -- LEFT ALT
            if pressed and not wasPressed and not nuiOpen then
                local veh = GetPlayerVehicle()
                if veh ~= 0 then OpenInsideMenu(veh) end
            elseif not pressed and wasPressed then
                if nuiOpen and currentContext == 'inside' then closeAllNui() end
            end
            wasPressed = pressed
            sleep = 0
        else
            if nuiOpen and currentContext == 'inside' then closeAllNui() end
            wasPressed = false
        end
        Wait(sleep)
    end
end)

-- Blockera kamera/aim/attack endast när utvändiga menyn är öppen
CreateThread(function()
    while true do
        if nuiOpen and currentContext == 'outside' then
            DisableControlAction(0, 1,  true)   -- LookLeftRight
            DisableControlAction(0, 2,  true)   -- LookUpDown
            DisableControlAction(0, 24, true)   -- Attack
            DisableControlAction(0, 25, true)   -- Aim
            DisableControlAction(0, 37, true)   -- Select Weapon
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- === NUI Callbacks ===
RegisterNUICallback('selectTarget', function(payload, cb)
    cb(1)
    if not cachedVeh or cachedVeh == 0 then return end

    if currentContext == 'outside' then
        if payload == 1 then
            ToggleLock(cachedVeh)
        elseif payload == 2 then
            ShowDoorsMenu()
        end
        return
    end

    if currentContext == 'inside' then
        if payload == 1 then
            ToggleSeatbelt()
        elseif payload == 2 then
            ToggleEngine()
        elseif payload == 3 then
            ToggleLock(cachedVeh)
        elseif payload == 4 then
            ShowDoorsMenu()
            return
        elseif payload == 5 then
            ShowWindowsMenu()
            return
        end
        -- refresha root-läget (target-lista) så state syns direkt
        OpenInsideMenu(cachedVeh)
    end
end)

RegisterNUICallback('selectMenu', function(data, cb)
    cb(1)
    if not data or not data.action then return end
    local action = tostring(data.action)

    if action == 'back' then
        if currentContext == 'inside' then
            OpenInsideMenu(cachedVeh)
        else
            OpenOutsideMenu(cachedVeh)
        end
        return
    end

    if action:find('door:') and cachedVeh then
        local id = tonumber(action:sub(6)); ToggleDoor(cachedVeh, id)
    elseif action:find('window:') and cachedVeh then
        local id = tonumber(action:sub(8)); ToggleWindow(cachedVeh, id)
    end
end)

RegisterNUICallback('closeMenu',   function(_, cb) cb(1) closeAllNui() end)
RegisterNUICallback('closeTarget', function(_, cb) cb(1) closeAllNui() end)
RegisterNUICallback('leftTarget',  function(_, cb) cb(1) closeAllNui() end)
