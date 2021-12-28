--====================================================================================
-- All work by jojos38 & Titch2000 & stefan750.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("Loading nodesGE...")



-- ============= VARIABLES =============
-- ============= VARIABLES =============



local function tick()
	if not settings.getValue("damageSync") then
		return
	end
	
	for k, v in ipairs(getAllVehicles()) do
		local vehId = v:getId()
		if isOwn(vehId) then
			veh:queueLuaCommand("nodesVE.getBeams()")
		else
			veh:queueLuaCommand("nodesVE.resyncBeams()")
		end
	end
end

local function sendBeams(data, gameVehicleID) -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	if not settings.getValue("damageSync") then
		return
	end
	
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send("Gn:"..serverVehicleID..":"..data)
		end
	end
end

local function applyBeams(data, serverVehicleID)
	if not settings.getValue("damageSync") then
		return
	end
	
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("nodesVE.applyBeams(\'"..data.."\')") -- Send nodes values
	end
end

local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == "n" then
		applyBeams(data, serverVehicleID)
	end
end



M.tick       = tick
M.handle     = handle
M.sendBeams  = sendBeams
M.applyBeams = applyBeams



print("nodesGE loaded")
return M
