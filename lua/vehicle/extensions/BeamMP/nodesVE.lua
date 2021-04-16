--====================================================================================
-- All work by jojos38 & Titch2000 & stefan750.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Node sync related test functions
--====================================================================================

local M = {}

local abs = math.abs
local min = math.min
local max = math.max



-- ============= VARIABLES =============
local beamCache = {}
local brokenBreakGroups = {}
local receivedBeams = {}
-- ============= VARIABLES =============



function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end



local function onInit()
	beamCache = {}
	local beamCount = 0
	
	for _, beam in pairs(v.data.beams) do
		-- exclude BEAM_PRESSURED, BEAM_LBEAM, BEAM_HYDRO, BEAM_SUPPORT, and beams that can not deform or break
		if beam.beamType ~= 3 and beam.beamType ~= 4 and beam.beamType ~= 6 and beam.beamType ~= 7
		   and (beam.beamDeform < math.huge or beam.beamStrength < math.huge) then
			beamCache[beam.cid] = {
				broken = obj:beamIsBroken(beam.cid),
				length = obj:getBeamRestLength(beam.cid),
				breakGroup = beam.breakGroup
			}
			beamCount = beamCount+1
		end
	end
	
	brokenBreakGroups = {}
	receivedBeams = {}
	
	--dump(beamCache)
	print("Cached "..beamCount.." beams for vehicle "..obj:getID())
end



local function onReset()
	-- Update cached beams on reset so we dont send everything again, other vehicle should receive reset event anyways
	for cid, cachedBeam in pairs(beamCache) do
		cachedBeam.broken = obj:beamIsBroken(cid)
		cachedBeam.length = obj:getBeamRestLength(cid)
	end
	
	brokenBreakGroups = {}
	receivedBeams = {}
	
	print("Reset beam cache for vehicle "..obj:getID())
end



local function getBeams()
	--print("getBeams "..obj:getID())
	local beams = {}
	local send = false
	local beamCount = 0
	
	for cid, cachedBeam in pairs(beamCache) do
		local broken = obj:beamIsBroken(cid)
		
		if broken then
			if broken ~= cachedBeam.broken and not brokenBreakGroups[cachedBeam.breakGroup] then
				beams[cid] = -1
				beamCount = beamCount+1
				cachedBeam.broken = broken
				send = true
				
				if cachedBeam.breakGroup then
					brokenBreakGroups[cachedBeam.breakGroup] = true
				end
			end
		else
			local length = obj:getBeamRestLength(cid)
			local diff = abs(length - cachedBeam.length)
			
			if diff > length*0.02 and diff > 0.01 then
				beams[cid] = round(length, 3)
				beamCount = beamCount+1
				cachedBeam.length = length
				send = true
			end
		end
		
		-- TODO: temporary packet size limit, remove once sorted on server side
		if beamCount >= 100 then
			obj:queueGameEngineLua("nodesGE.sendBeams(\'"..jsonEncode(beams).."\', "..obj:getID()..")") -- Send it to GE lua
			print("Send "..beamCount.." beams "..obj:getID()..": "..jsonEncode(beams))
			
			beams = {}
			send = false
			beamCount = 0
		end
	end
	
	if send then
		obj:queueGameEngineLua("nodesGE.sendBeams(\'"..jsonEncode(beams).."\', "..obj:getID()..")") -- Send it to GE lua
		print("Send "..beamCount.." beams "..obj:getID()..": "..jsonEncode(beams))
	end
end



local function applyBeams(data)
	local beams = jsonDecode(data)

	for cid, length in pairs(beams) do
		if length < 0 then
			if not obj:beamIsBroken(cid) then
				obj:breakBeam(cid)
				beamstate.beamBroken(cid,1)
			end
		else
			receivedBeams[cid] = {
				length = length,
				rate = abs(length - obj:getBeamRestLength(cid))/1
			}
		end
	end
end



local function updateGFX(dt)
	for cid, beam in pairs(receivedBeams) do
		local currentLen = obj:getBeamRestLength(cid)
		local dif = beam.length - currentLen
		local rate = beam.rate*dt
		
		if abs(dif) > 0.01 then
			local length = currentLen + min(max(dif, -rate), rate)
			obj:setBeamLength(cid, length)
		else
			receivedBeams[cid] = nil
		end
	end
end



M.onInit             = onInit
M.onExtensionLoaded  = onInit
M.onReset            = onReset
M.applyBeams         = applyBeams
M.getBeams           = getBeams
M.updateGFX          = updateGFX


return M
