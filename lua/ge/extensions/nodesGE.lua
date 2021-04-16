--====================================================================================
-- All work by jojos38 & Titch2000 & stefan750.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("Loading nodesGE...")



-- ============= VARIABLES =============
-- ============= VARIABLES =============



local function tick()
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("nodesVE.getBeams()")
		end
	end
end

local function sendBeams(data, gameVehicleID) -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send("Xn:"..serverVehicleID..":"..data)
		end
	end
end

local function applyBeams(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("nodesVE.applyBeams(\'"..data.."\')") -- Send nodes values
	end
end

local function handle(rawData)
	--print("nodesGE.handle: "..rawData)
	local code = string.sub(rawData, 1, 1)
	if code == "n" then
		rawData = string.sub(rawData,3)
		local serverVehicleID = string.match(rawData,"(%w+)%:")
		local data = string.match(rawData,":(.*)")
		applyBeams(data, serverVehicleID)
	end
end



M.tick       = tick
M.handle     = handle
M.sendBeams  = sendBeams
M.applyBeams = applyBeams



print("nodesGE loaded")
return M
