Config = {}

-- Avstånd för att se qb-target alternativ på fordon
Config.TargetVehicleDistance = 2.5

-- Dörrar & fönsterlistor
Config.DoorList = {
    { id = 0, label = 'Vänster fram' },
    { id = 1, label = 'Höger fram' },
    { id = 2, label = 'Vänster bak' },
    { id = 3, label = 'Höger bak' },
    { id = 4, label = 'Motorhuv' },
    { id = 5, label = 'Bagage' },
}

Config.WindowList = {
    { id = 0, label = 'Vänster fram' },
    { id = 1, label = 'Höger fram' },
    { id = 2, label = 'Vänster bak' },
    { id = 3, label = 'Höger bak' },
}

-- Ikoner (Font Awesome)
Config.Icons = {
    Locks   = 'fas fa-lock',
    Unlock  = 'fas fa-unlock',
    Doors   = 'fas fa-car-side',
    Windows = 'fas fa-window-maximize',
    Seatbelt= 'fas fa-user-shield',
    Back    = 'fas fa-arrow-left',
}

-- HOLD ALT i bilen/utanför för att hålla menyn öppen
-- Rensa bort andra scripts' fordonslabels (så endast detta script syns)
Config.PurgeVehicleLabels = {
    "Open Trunk", "Open Hood", "Seat", "Trunk", "Hood",
    "Inspect Vehicle", "Repair Vehicle", "Search Vehicle",
    "Toggle Door", "Vehicle Info"
}

-- Specifika modeller att rensa (valfritt)
Config.PurgeModels = {
    -- { models = { `adder`, `sultan` }, labels = { "Open Trunk", "Open Hood" } }
}
