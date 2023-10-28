local CurrentAction     = nil
local CurrentActionMsg  = nil
local CurrentActionData = nil
local Licenses          = {}
local CurrentTest       = nil
local CurrentTestType   = nil
local CurrentVehicle    = nil
local CurrentCheckPoint, DriveErrors = 0, 0
local LastCheckPoint    = -1
local CurrentBlip       = nil
local CurrentZoneType   = nil
local IsAboveSpeedLimit = false
local LastVehicleHealth = nil

function DrawMissionText(msg, time)
	ClearPrints()
	BeginTextCommandPrint('STRING')
	AddTextComponentSubstringPlayerName(msg)
	EndTextCommandPrint(time, true)
end

function StartTheoryTest()
	CurrentTest = 'theory'

	SendNUIMessage({
		openQuestion = true
	})

	ESX.SetTimeout(200, function()
		SetNuiFocus(true, true)
	end)


end

function StopTheoryTest(success)
	CurrentTest = nil

	SendNUIMessage({
		openQuestion = false
	})

	SetNuiFocus(false)

	if success then
		TriggerServerEvent('esx_dmvschool:addLicense', 'dmv')
		ESX.ShowNotification(TranslateCap('passed_test'))
	else
		ESX.ShowNotification(TranslateCap('failed_test'))
	end
end

function StartDriveTest(type)
	ESX.Game.SpawnVehicle(Config.VehicleModels[type], vector3(Config.Zones.VehicleSpawnPoint.Pos.x, Config.Zones.VehicleSpawnPoint.Pos.y, Config.Zones.VehicleSpawnPoint.Pos.z), Config.Zones.VehicleSpawnPoint.Pos.h, function(vehicle)
		CurrentTest       = 'drive'
		CurrentTestType   = type
		CurrentCheckPoint = 0
		LastCheckPoint    = -1
		CurrentZoneType   = 'residence'
		DriveErrors       = 0
		IsAboveSpeedLimit = false
		CurrentVehicle    = vehicle
		LastVehicleHealth = GetEntityHealth(vehicle)

		local playerPed   = PlayerPedId()
		TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		SetVehicleFuelLevel(vehicle, 100.0)
		DecorSetFloat(vehicle, "_FUEL_LEVEL", GetVehicleFuelLevel(vehicle))
	end)
end

function StopDriveTest(success)
	if success then
		TriggerServerEvent('esx_dmvschool:addLicense', CurrentTestType)
		ESX.ShowNotification(TranslateCap('passed_test'))
	else
		ESX.ShowNotification(TranslateCap('failed_test'))
	end

	CurrentTest     = nil
	CurrentTestType = nil
end

function SetCurrentZoneType(type)
CurrentZoneType = type
end

RegisterNUICallback('question', function(data, cb)
	SendNUIMessage({
		openSection = 'question'
	})

	cb()
end)

RegisterNUICallback('close', function(data, cb)
	StopTheoryTest(true)
	cb()
end)

RegisterNUICallback('kick', function(data, cb)
	StopTheoryTest(false)
	cb()
end)

AddEventHandler('esx_dmvschool:hasExitedMarker', function(zone)
	CurrentAction = nil
end)

RegisterNetEvent('esx_dmvschool:loadLicenses')
AddEventHandler('esx_dmvschool:loadLicenses', function(licenses)
	Licenses = licenses
end)

Blips = {}

Blips.Map = {
  {name = "Auto-Ecole", color = 3, id = 76, pos = vector3(240.72024536133,-1379.0277099609,33.741779327393)}, 
}
local AllBlips = {}

Citizen.CreateThread(function()
      Citizen.Wait(1000)
    for _,v in pairs(Blips.Map) do
        local blipMap = AddBlipForCoord(v.pos)
        SetBlipSprite(blipMap, v.id)
        SetBlipDisplay(blipMap, 4)
        SetBlipScale(blipMap, 0.5)
        SetBlipColour(blipMap, v.color)
        SetBlipAsShortRange(blipMap, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(v.name)
        EndTextCommandSetBlipName(blipMap)
        SetBlipPriority(blipMap, 5)
    end
end)

--Display markers
CreateThread(function()
	while true do
		local sleep = 1500
		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)

		for k,v in pairs(Config.Zones) do
			local Pos = vector3(v.Pos.x, v.Pos.y, v.Pos.z)
			if(v.Type ~= -1 and #(coords - Pos) < Config.DrawDistance) then
				sleep = 0
				DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
			end
		end

		if CurrentTest == 'theory' then
			
			sleep = 0
			DisableControlAction(0, 1, true) -- LookLeftRight
			DisableControlAction(0, 2, true) -- LookUpDown
			DisablePlayerFiring(playerPed, true) -- Disable weapon firing
			DisableControlAction(0, 142, true) -- MeleeAttackAlternate
			DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
		end

		if CurrentTest == 'drive' then
			sleep = 0
			local nextCheckPoint = CurrentCheckPoint + 1

			if Config.CheckPoints[nextCheckPoint] == nil then
				if DoesBlipExist(CurrentBlip) then
					RemoveBlip(CurrentBlip)
				end

				CurrentTest = nil

				ESX.ShowNotification(TranslateCap('driving_test_complete'))

				if DriveErrors < Config.MaxErrors then
					StopDriveTest(true)
				else
					StopDriveTest(false)
				end
			else
				if CurrentCheckPoint ~= LastCheckPoint then
					if DoesBlipExist(CurrentBlip) then
						RemoveBlip(CurrentBlip)
					end

					CurrentBlip = AddBlipForCoord(Config.CheckPoints[nextCheckPoint].Pos.x, Config.CheckPoints[nextCheckPoint].Pos.y, Config.CheckPoints[nextCheckPoint].Pos.z)
					SetBlipRoute(CurrentBlip, 1)

					LastCheckPoint = CurrentCheckPoint
				end
            
				local Pos = vector3(Config.CheckPoints[nextCheckPoint].Pos.x,Config.CheckPoints[nextCheckPoint].Pos.y,Config.CheckPoints[nextCheckPoint].Pos.z)
				local distance = #(coords - Pos)
            
				if distance <= Config.DrawDistance then
					DrawMarker(1, Config.CheckPoints[nextCheckPoint].Pos.x, Config.CheckPoints[nextCheckPoint].Pos.y, Config.CheckPoints[nextCheckPoint].Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.5, 1.5, 1.5, 102, 204, 102, 100, false, true, 2, false, false, false, false)
				end

				if distance <= 3.0 then
					Config.CheckPoints[nextCheckPoint].Action(playerPed, CurrentVehicle, SetCurrentZoneType)
					CurrentCheckPoint = CurrentCheckPoint + 1
				end
			end
		end
		
		local isInMarker  = false
		local currentZone = nil

		for k,v in pairs(Config.Zones) do
			local Pos = vector3(v.Pos.x, v.Pos.y, v.Pos.z)
			if(#(coords - Pos) < v.Size.x) then
				sleep = 0
				isInMarker  = true
				currentZone = k
			end
		end

		if not isInMarker and HasAlreadyEnteredMarker then
			HasAlreadyEnteredMarker = false
			TriggerEvent('esx_dmvschool:hasExitedMarker', LastZone)
		end
		Wait(sleep)
	end
end)

-- Speed / Damage control
CreateThread(function()
	while true do
		local sleep = 1500

		if CurrentTest == 'drive' then
			sleep = 0
			local playerPed = PlayerPedId()

			if IsPedInAnyVehicle(playerPed, false) then

				local vehicle      = GetVehiclePedIsIn(playerPed, false)
				local speed        = GetEntitySpeed(vehicle) * Config.SpeedMultiplier
				local tooMuchSpeed = false

				for k,v in pairs(Config.SpeedLimits) do
					if CurrentZoneType == k and speed > v then
						tooMuchSpeed = true

						if not IsAboveSpeedLimit then
							DriveErrors       = DriveErrors + 1
							IsAboveSpeedLimit = true

							ESX.ShowNotification(TranslateCap('driving_too_fast', v))
							ESX.ShowNotification(TranslateCap('errors', DriveErrors, Config.MaxErrors))
						end
					end
				end

				if not tooMuchSpeed then
					IsAboveSpeedLimit = false
				end

				local health = GetEntityHealth(vehicle)
				if health < LastVehicleHealth then

					DriveErrors = DriveErrors + 1

					ESX.ShowNotification(TranslateCap('you_damaged_veh'))
					ESX.ShowNotification(TranslateCap('errors', DriveErrors, Config.MaxErrors))

					-- avoid stacking faults
					LastVehicleHealth = health
					Wait(1500)
				end
			end
		end
		Wait(sleep)
	end
end)

AddEventHandler ('OpenDMVSchoolMenu', function ()
	OxOpenDMVSchoolMenu()
end)

exports.ox_target:addSphereZone({
    coords = Config.Locations,
    radius = 1,
    debug = drawZones,
    options = {
        {
            event = 'OpenDMVSchoolMenu',
            icon = 'fa-solid fa-car',
            label = 'Auto Ecole',
        }
    }
})

function OxOpenDMVSchoolMenu()
	local ownedLicenses = {}

	for i=1, #Licenses, 1 do
		ownedLicenses[Licenses[i].type] = true
	end

	Options = {}

	if not ownedLicenses['dmv'] then
		Options[#Options + 1] = {
			title = TranslateCap('theory_test'),
			description = Config.Prices.dmv..' $',
			icon = 'car',
			onSelect = function()
				ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
					if haveMoney then
						StartTheoryTest()
					else
						ESX.ShowNotification(TranslateCap('not_enough_money'))
					end
				end, 'dmv')
			end,
		}
	else 
		Options[#Options + 1] = {
			title = TranslateCap('theory_test'),
			description = TranslateCap('already_obtained')..' '..Config.Prices.dmv..' $',
			disabled = true,
			icon = 'car',
			onSelect = function()
				ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
					if haveMoney then
						StartTheoryTest()
					else
						ESX.ShowNotification(TranslateCap('not_enough_money'))
					end
				end, 'dmv')
			end,
		}
	end

	if ownedLicenses['dmv'] then
		if not ownedLicenses['drive'] then
			Options[#Options + 1] = {
				title = TranslateCap('road_test_car'),
				description = Config.Prices.drive..' $',
				icon = 'car',
				onSelect = function()
					ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
						if haveMoney then
							StartDriveTest("drive")
						else
							ESX.ShowNotification(TranslateCap('not_enough_money'))
						end
					end, "drive")
				end,
			}
		else
			Options[#Options + 1] = {
				title = TranslateCap('road_test_car'),
				description = TranslateCap('already_obtained')..' '..Config.Prices.drive..' $',
				disabled = true,
				icon = 'car',
				onSelect = function()
					ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
						if haveMoney then
							StartDriveTest("drive")
						else
							ESX.ShowNotification(TranslateCap('not_enough_money'))
						end
					end, "drive")
				end,
			}
		end

		if not ownedLicenses['drive_bike'] then
			Options[#Options + 1] = {
				title = TranslateCap('road_test_bike'),
				description = Config.Prices.drive_bike..' $',
				icon = 'car',
				onSelect = function()
					ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
						if haveMoney then
							StartDriveTest("drive_bike")
						else
							ESX.ShowNotification(TranslateCap('not_enough_money'))
						end
					end, "drive_bike")
				end,
			}
		else
			Options[#Options + 1] = {
				title = TranslateCap('road_test_bike'),
				description = TranslateCap('already_obtained')..' '..Config.Prices.drive_bike..' $',
				disabled = true,
				icon = 'car',
				onSelect = function()
					ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
						if haveMoney then
							StartDriveTest("drive_bike")
						else
							ESX.ShowNotification(TranslateCap('not_enough_money'))
						end
					end, "drive_bike")
				end,
			}
		end

		if not ownedLicenses['drive_truck'] then
			Options[#Options + 1] = {
				title = TranslateCap('road_test_truck'),
				description = Config.Prices.drive_truck..' $',
				icon = 'car',
				onSelect = function()
					ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
						if haveMoney then
							StartDriveTest("drive_truck")
						else
							ESX.ShowNotification(TranslateCap('not_enough_money'))
						end
					end, "drive_truck")
				end,
			}
		else
			Options[#Options + 1] = {
				title = TranslateCap('road_test_truck'),
				description = TranslateCap('already_obtained')..' '..Config.Prices.drive_truck..' $',
				disabled = true,
				icon = 'car',
				onSelect = function()
					ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
						if haveMoney then
							StartDriveTest("drive_truck")
						else
							ESX.ShowNotification(TranslateCap('not_enough_money'))
						end
					end, "drive_truck")
				end,
			}
		end
	end
	lib.registerContext({
		id = 'dmv_shool',
		title = TranslateCap("driving_school"),
		options = Options
	})
	lib.showContext('dmv_shool')
end

