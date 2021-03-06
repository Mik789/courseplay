
-- this function never changes lx or lz
function courseplay:handleMode8(vehicle, load, unload, allowedToDrive, lx, lz, dt, tx, ty, tz, nx, ny, nz)
	load = load and (not vehicle.cp.runReset or vehicle.cp.runCounter == 0)
	courseplay:debug(('%s: handleMode8(load=%s, unload=%s, allowedToDrive=%s)'):format(nameNum(vehicle), tostring(load), tostring(unload), tostring(allowedToDrive)), 23);

	if not vehicle.cp.workToolAttached then
		return false, lx, lz;
	end;


	-- LOADING
	if load then
		courseplay:doTriggerRaycasts(vehicle, 'specialTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		-- lx, lz never changed by this call
		allowedToDrive, lx, lz = courseplay:refillWorkTools(vehicle, vehicle.cp.refillUntilPct, allowedToDrive, lx, lz);

	-- UNLOADING
	elseif unload then
		local workTool = vehicle.cp.workTools[1];
		local tankIsFull = false
		
		if vehicle.cp.prevFillLevelPct then
			vehicle.cp.isUnloading = vehicle.cp.totalFillLevelPercent < vehicle.cp.prevFillLevelPct;
		end;

		-- liquid manure sprayers/transporters
		if workTool.cp.isLiquidManureSprayer or workTool.cp.isLiquidManureOverloader then
			CpManager:setGlobalInfoText(vehicle, 'OVERLOADING_POINT');
			--                                            courseplay:handleSpecialTools(vehicle, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload)
			local isSpecialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle, workTool, nil,    nil,   nil,    allowedToDrive, nil,   true  );
			if not isSpecialTool then
				-- trailer
				if workTool.cp.isLiquidManureOverloader and workTool.overloading ~= nil and courseplay:getTrailerInPipeRangeState(workTool) > 0 and not workTool.isOverloadingActive then
					for trailer,_ in pairs(workTool.overloading.trailersInRange) do
						courseplay:setOwnFillLevelsAndCapacities(trailer)
						if trailer.unloadTrigger ~= nil and trailer.cp.fillLevel < trailer.cp.capacity then
							workTool:setOverloadingActive(true);
							vehicle.cp.lastMode8UnloadTriggerId = trailer.unloadTrigger.triggerId;
							courseplay:debug(('    %s: [trailer] setOverloadingActive(true), triggerId=%d'):format(nameNum(workTool), vehicle.cp.lastMode8UnloadTriggerId), 23);
						end;
					end;

				-- ManureLager
				elseif workTool.setIsReFilling ~= nil and workTool.ReFillTrigger ~= nil and workTool.fillLevel > 0 and not workTool.isReFilling and workTool.ReFillTrigger.fillLevel < workTool.ReFillTrigger.capacity then
					workTool:setIsReFilling(true);
					vehicle.cp.lastMode8UnloadTriggerId = workTool.ReFillTrigger.manureTrigger;
					courseplay:debug(('    %s: [ManureLager] setIsReFilling(true), triggerId=%d'):format(nameNum(workTool), vehicle.cp.lastMode8UnloadTriggerId), 23);

				--Liquid Manure Sell Triggers and BGA Extension Mod
				elseif workTool.cp.isLiquidManureOverloader then
					local triggers = g_currentMission.trailerTipTriggers[workTool]
					if triggers ~= nil and triggers[1].acceptedFillTypes ~= nil and triggers[1].acceptedFillTypes[workTool.cp.fillType] and workTool.cp.fillType == g_fillTypeManager.nameToIndex.liquidManure then

						local inBGAExtensionTrigger = triggers[1].bga and triggers[1].bga.fermenter_bioOK
						local goForUnloading = workTool.cp.fillLevel > 0 and workTool:getDischargeState() == Trailer.TIPSTATE_CLOSED 

						--Stop Unloading to BGA Extension
						if inBGAExtensionTrigger and not goForUnloading and triggers[1].bga.BGA_Bonus >= triggers[1].bga.BGA_Bonus_Capacity*0.99 and (workTool:getDischargeState() == Trailer.TIPSTATE_OPENING or workTool:getDischargeState() == Trailer.TIPSTATE_OPEN) then
							workTool:toggleTipState(triggers[1],1);	
							courseplay:debug('                BGA Extension Mod is full resuming course', 23);

						--Start Unloading to BGA Extension
						elseif inBGAExtensionTrigger and triggers[1].bga.BGA_Bonus < triggers[1].bga.BGA_Bonus_Capacity*0.99  and goForUnloading then
							workTool:toggleTipState(triggers[1],1);	
							courseplay:debug('                Unloading at BGA Extension Mod', 23);

						--Liquid Manure Sell Trigger
						elseif goForUnloading and not inBGAExtensionTrigger then
							workTool:toggleTipState(triggers[1],1);	
							courseplay:debug('                Unloading at Liquid Manure Sell Trigger', 23);
						end;
					else 
						--Should only happen if user tries to sell disgeate. TODO mabye? Add a messeage on screen saying unaccepted fill type
						courseplay:debug('                Unsupported  filltype or trigger', 23);	
					end		
				end;
			end;

		-- fuel trailers
		elseif workTool.cp.isFuelTrailer then
			-- do nothing

		end

		-- water trailers
		if workTool.cp.isWaterTrailer then
			-- check if workTool is in waterReceiver trigger
			courseplay:debug(('    %s: unload'):format(nameNum(workTool)), 23);
			if not workTool.cp.waterReceiverTrigger then
				for _,obj in pairs(courseplay.triggers.waterReceivers) do
					-- WaterMod
					if obj.isWaterMod then
						courseplay:debug(('        [WATERMOD] obj.isWaterMod'):format(nameNum(workTool)), 23);
						for i,trailer in pairs(obj.WaterTrailers) do
							courseplay:debug(('            check trailer %q against workTool'):format(nameNum(trailer)), 23);
							if trailer == workTool then
								courseplay:debug('                workTool.cp.waterReceiverTrigger = obj', 23);
								workTool.cp.waterReceiverTrigger = obj;
								break;
							end;
						end;

					-- Schweinezucht water
					elseif obj.isSchweinezuchtWater then
						courseplay:debug(('        [SCHWEINEZUCHT WATER] obj.isSchweinezuchtWater'):format(nameNum(workTool)), 23);
						if obj.WaterTrailerInRange then
							courseplay:debug(('            check trailer %q against workTool'):format(nameNum(obj.WaterTrailerInRange)), 23);
							if obj.WaterTrailerInRange == workTool then
								courseplay:debug('                workTool.cp.waterReceiverTrigger = obj', 23);
								workTool.cp.waterReceiverTrigger = obj;
							end;
						end;

					-- Greenhouse
					elseif obj.isGreenhouse then
						courseplay:debug(('        [GREENHOUSE] obj.isGreenhouse'):format(nameNum(workTool)), 23);
						for i,trailer in pairs(obj.waterTrailers) do
							courseplay:debug(('            check trailer %q against workTool'):format(nameNum(trailer)), 23);
							if trailer == workTool then
								courseplay:debug('                workTool.cp.waterReceiverTrigger = obj', 23);
								workTool.cp.waterReceiverTrigger = obj;
								break;
							end;
						end;
					end;

					if workTool.cp.waterReceiverTrigger then
						break;
					end
				end
				
				--standard water tiptriggers cow, sheep and pigs
				if not workTool.cp.waterReceiverTrigger then	
					local triggers = g_currentMission.trailerTipTriggers[workTool]
					if triggers ~= nil then
						if workTool:getDischargeState() == Trailer.TIPSTATE_OPENING or workTool:getDischargeState() == Trailer.TIPSTATE_OPEN then
							vehicle.cp.isUnloading = true
						else
							if workTool:getDischargeState() == Trailer.TIPSTATE_CLOSED then
								workTool:toggleTipState(triggers[1],1);
							elseif workTool:getDischargeState() == Trailer.TIPSTATE_CLOSING then
								vehicle.cp.isUnloading = false
								tankIsFull = true
							end							
						end
					end
				end				
			end;

			-- start unloading placeables
			local tank = workTool.cp.waterReceiverTrigger;
			
			if tank then
				 --courseplay:debug(('        tank.WaterTrailerActivatable=%s, tank.waterTrailerActivatable=%s'):format(tostring(tank.WaterTrailerActivatable), tostring(tank.waterTrailerActivatable)), 23);
				local activatable, isFilling, setterFn;
				if tank.isWaterMod then -- WaterMod
					activatable = tank.WaterTrailerActivatable;
					isFilling = tank.isWaterFilling;
					setterFn = 'setIsWaterFilling';
				elseif tank.isSchweinezuchtWater then -- Schweinezucht water
					activatable = tank.WaterTrailerActivatable;
					isFilling = tank.isWaterTankFilling;
					setterFn = 'setIsWaterTankFilling';
				elseif tank.isGreenhouse then -- Greenhouse
					activatable = tank.waterTrailerActivatable;
					isFilling = tank.isWaterTankFilling;
					setterFn = 'setIsWaterTankFilling';
				else -- no valid receiving trigger
					return false, lx, lz;
				end;

				if tank.waterTrailerActivatable ~= nil and not isFilling then
					courseplay:debug(('        isWaterMod=%s, isSchweinezuchtWater=%s, isGreenhouse=%s, getIsActivatable()=%s, isFilling=%s -> %s(true)'):format(tostring(tank.isWaterMod), tostring(tank.isSchweinezuchtWater), tostring(tank.isGreenhouse), tostring(isActivatable), tostring(isFilling), setterFn), 23);
					if tank.isGreenhouse then
						tank[setterFn](tank, true, workTool);
						vehicle.cp.isUnloading = true
						
					else
						tank[setterFn](tank, true);
					end;
				else
					tankIsFull = tank.waterTankFillLevel == tank.waterTankCapacity
				end;
			end;
				
		end;


		local driveOn = vehicle.cp.totalFillLevelPercent == 0 or tankIsFull ;
		if not driveOn and vehicle.cp.prevFillLevelPct ~= nil then
			if vehicle.cp.totalFillLevelPercent > 0 and vehicle.cp.isUnloading then
				courseplay:setCustomTimer(vehicle, 'fillLevelChange', 7);
			else
				-- courseplay:debug(('        isUnloading=%s, totalFillLevelPercent=%.2f, prevFillLevelPct=%.2f, equal=%s, followAtFillLevel=%d, timerThrough=%s'):format(tostring(vehicle.cp.isUnloading), vehicle.cp.totalFillLevelPercent, vehicle.cp.prevFillLevelPct, tostring(vehicle.cp.totalFillLevelPercent == vehicle.cp.prevFillLevelPct), vehicle.cp.followAtFillLevel, tostring(courseplay:timerIsThrough(vehicle, 'fillLevelChange', false))), 23);
				if vehicle.cp.totalFillLevelPercent == vehicle.cp.prevFillLevelPct and vehicle.cp.totalFillLevelPercent < vehicle.cp.followAtFillLevel and courseplay:timerIsThrough(vehicle, 'fillLevelChange', false) then
					driveOn = true; -- drive on if fillLevelPct doesn't change for 7 seconds and fill level is < followAtFillLevel
					vehicle.cp.isUnloading = false;
					courseplay:debug('        no fillLevel change for 7 seconds -> driveOn', 23);
				end;
			end;
		elseif driveOn then
			courseplay:debug('        totalFillLevelPercent == 0 or tank.waterTankFillLevel == tank.waterTankCapacity -> driveOn', 23);
			vehicle.cp.isUnloading = false;
		end;

		vehicle.cp.prevFillLevelPct = vehicle.cp.totalFillLevelPercent;

		if driveOn and not vehicle.cp.isUnloading then
			courseplay:cancelWait(vehicle);
			if workTool.cp.waterReceiverTrigger then
				courseplay:debug('        driveOn -> set waterReceiverTrigger to nil', 23);
				workTool.cp.waterReceiverTrigger = nil;
			end;
		end;
	end;

	return allowedToDrive, lx, lz;
end;

function courseplay:resetMode8(vehicle)
	vehicle.cp.prevFillLevelPct = nil;
	vehicle.cp.isUnloaded = true;
	vehicle.cp.isUnloading = false;
	if courseplay:getCustomTimerExists(vehicle,'fillLevelChange')  then 
		--print("reset existing timer")
		courseplay:resetCustomTimer(vehicle,'fillLevelChange',true)
	end
	if  vehicle.cp.waypointIndex >= vehicle.cp.waitPoints[vehicle.cp.numWaitPoints] and vehicle.cp.fillTrigger == nil then
		courseplay:changeRunCounter(vehicle, false)
	end;
end
