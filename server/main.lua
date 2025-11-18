local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('qb-vehicle-target:server:log', function(msg)
    local src = source
    print(('[qb-vehicle-target] %s'):format(msg))
end)
