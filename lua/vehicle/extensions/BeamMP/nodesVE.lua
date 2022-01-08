--====================================================================================
-- All work by jojos38 & Titch2000 & stefan750.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Visual vehicle damage sync
--====================================================================================

local M = {}

local abs = math.abs
local min = math.min
local max = math.max



local damageThreshold = 1          -- How much the beamstate.damage value needs to change before syncing
local beamDeformThreshold = 0.02   -- Relative length change after which a beam will be synced, 0.02 means length change by 2%
local beamDeformMin = 0.01         -- Total length change after which a beam will be synced (m), 0.01 means length change by 1cm
local beamApplyTime = 0.5          -- How quickly the damage will be applied (s), 1 means incoming damage will be interpolated over 1 second



-- ============= VARIABLES =============
local beamCache = {}
local brokenBreakGroups = {}
local beamsToUpdate = {}
local lastDamage = 0
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
			beamCache[beam.cid] = obj:beamIsBroken(beam.cid) and -1 or obj:getBeamRestLength(beam.cid)*((beam.beamPrecompressionTime or 0) > 0 and beam.beamPrecompression or 1)
			beamCount = beamCount+1
		end
	end
	
	brokenBreakGroups = {}
	beamsToUpdate = {}
	
	lastDamage = 0
	
	--dump(beamCache)
	print("Cached "..beamCount.." beams for vehicle "..obj:getID())
end



local function onReset()
	-- Update cached beams on reset so we dont send everything again, other vehicle should receive reset event anyways
	for cid, cachedLength in pairs(beamCache) do
		local beam = v.data.beams[cid]
		beamCache[cid] = obj:beamIsBroken(cid) and -1 or obj:getBeamRestLength(cid)*((beam.beamPrecompressionTime or 0) > 0 and beam.beamPrecompression or 1)
	end
	
	brokenBreakGroups = {}
	beamsToUpdate = {}
	
	lastDamage = 0
	
	print("Reset beam cache for vehicle "..obj:getID())
end



-- Compare all beams with cache and send any changes to server
local function getBeams()
	-- Skip if beamstate.damage has not changed
	if abs(beamstate.damage - lastDamage) < damageThreshold then
		return
	end
	
	--print("getBeams "..obj:getID())
	local beams = {}
	local send = false
	local beamCount = 0
	
	for cid, cachedLength in pairs(beamCache) do
		-- skip already broken beams
		if cachedLength >= 0 then
			-- beam newly broken
			if obj:beamIsBroken(cid) then
				beamCache[cid] = -1
				
				-- Only one beam per breakgroup is needed, the other ones will break automatically
				local breakGroup = v.data.beams[cid].breakGroup
				if not breakGroup or not brokenBreakGroups[breakGroup] then
					beams[cid] = -1
					beamCount = beamCount+1
					send = true
					
					if breakGroup then
						brokenBreakGroups[breakGroup] = true
					end
				end
			else -- check if beam changed length
				local curLength = obj:getBeamRestLength(cid)
				local diff = abs(curLength - cachedLength)
				
				if diff > curLength*beamDeformThreshold and diff > beamDeformMin then
					beams[cid] = round(curLength, 4)
					beamCount = beamCount+1
					beamCache[cid] = curLength
					send = true
				end
			end
		end
		--[[
		-- TODO: temporary packet size limit, remove once sorted on server side
		if beamCount >= 100 then
			obj:queueGameEngineLua("nodesGE.sendBeams(\'"..jsonEncode(beams).."\', "..obj:getID()..")") -- Send it to GE lua
			print("Send "..beamCount.." beams "..obj:getID()..": "..jsonEncode(beams))
			
			beams = {}
			send = false
			beamCount = 0
		end
		--]]
	end
	
	if send then
		obj:queueGameEngineLua("nodesGE.sendBeams(\'"..jsonEncode(beams).."\', "..obj:getID()..")") -- Send it to GE lua
		print("Send "..beamCount.." beams "..obj:getID())--..": "..jsonEncode(beams))
	end
	
	lastDamage = beamstate.damage
end



local function applyBeams(data)
	local beams = jsonDecode(data)

	for cidStr, length in pairs(beams) do
		-- JSON keys are always strings, so we need to convert it back to a number
		local cid = tonumber(cidStr)
		
		-- Ignore beam if it isn't in the cache
		if beamCache[cid] then
			if length < 0 then
				if not obj:beamIsBroken(cid) then
					obj:breakBeam(cid)
					beamstate.beamBroken(cid,1)
				end
			else
				local curLength = obj:getBeamRestLength(cid)

				beamsToUpdate[cid] = {
					oldLength = curLength,
					newLength = length,
					progress = 0
				}
			end
			
			beamCache[cid] = length
		end
	end
	
	print("Apply beams for vehicle "..obj:getID())
end



-- Compare all beams with the cache and correct if necessary
local function resyncBeams()
	-- Skip if beamstate.damage has not changed
	if abs(beamstate.damage - lastDamage) < damageThreshold then
		return
	end
	
	for cid, cachedLength in pairs(beamCache) do
		local curLength = obj:getBeamRestLength(cid)
		local diff = abs(cachedLength - curLength)
		
		if cachedLength < 0 then
			if not obj:beamIsBroken(cid) then
				obj:breakBeam(cid)
				beamstate.beamBroken(cid,1)
			end
		elseif diff > curLength*beamDeformThreshold and diff > beamDeformMin then
			beamsToUpdate[cid] = {
				oldLength = curLength,
				newLength = cachedLength,
				progress = 0
			}
		end
	end
	
	print("Resync beams for vehicle "..obj:getID())
	
	lastDamage = beamstate.damage
end



local function updateGFX(dt)
	local updatingBeams = false
	for cid, beam in pairs(beamsToUpdate) do
		-- Interpolate beam length
		if beam.progress < 1 then
			beam.progress = min(beam.progress + dt/beamApplyTime, 1)
			local length = lerp(beam.oldLength, beam.newLength, beam.progress)
			obj:setBeamLength(cid, length)
			
			updatingBeams = true
		else
			beamsToUpdate[cid] = nil
		end
	end
	
	if updatingBeams then
		lastDamage = beamstate.damage
	end
end



M.onInit             = onInit
M.onExtensionLoaded  = onInit
M.onReset            = onReset
M.applyBeams         = applyBeams
M.getBeams           = getBeams
M.resyncBeams        = resyncBeams
M.updateGFX          = updateGFX


return M
