require("config")
require("LinkedList")
local json = require("json")

------------------------------------------------------------
--[[Method that handle creation and deletion of entities]]--
------------------------------------------------------------ 
function OnBuiltEntity(event)
	local entity = event.created_entity
	if not (entity and entity.valid) then return end
	
	local player = false
	if event.player_index then player = game.players[event.player_index] end
	
	local spawn
	if player and player.valid then
		spawn = game.players[event.player_index].force.get_spawn_position(entity.surface)
	else
		spawn = game.forces["player"].get_spawn_position(entity.surface)
	end
	local x = entity.position.x - spawn.x
	local y = entity.position.y - spawn.y
	
	local name = entity.name
	if name == "entity-ghost" then name = entity.ghost_name end
	
	if ENTITY_TELEPORTATION_RESTRICTION and (name == INPUT_CHEST_NAME or name == OUTPUT_CHEST_NAME or name == INPUT_TANK_NAME or name == OUTPUT_TANK_NAME) then
		if (x < global.config.PlacableArea and x > 0-global.config.PlacableArea and y < global.config.PlacableArea and y > 0-global.config.PlacableArea) then
			--only add entities that are not ghosts
			if entity.type ~= "entity-ghost" then
				AddEntity(entity)
			end
		else
			if player and player.valid then
				-- Tell the player what is happening
				if player then player.print("Attempted placing entity outside allowed area (placed at x "..x.." y "..y.." out of allowed "..global.config.PlacableArea..")") end
				-- kill entity, try to give it back to the player though
				if not player.mine_entity(entity, true) then
					entity.destroy()
				end
			else
				-- it wasn't placed by a player, we can't tell em whats wrong
				entity.destroy()
			end
		end
	else
		--only add entities that are not ghosts
		if entity.type ~= "entity-ghost" then
			AddEntity(entity)
		end
	end
end

function AddAllEntitiesOfNames(names)
	local filters = {}
	for name in names do
		filters[#filters + 1] = {name = name}
	end
	for k, surface in pairs(game.surfaces) do
		AddEntities(surface.find_entities_filtered(filters))
	end
end

function AddEntities(entities)
	for k, entity in pairs(entities) do
		AddEntity(entity)
	end
end

function AddEntity(entity)
	if entity.name == INPUT_CHEST_NAME then
		--add the chests to a lists if these chests so they can be interated over
		global.inputChests[entity.unit_number] = 
		{
			entity = entity,
			inv = entity.get_inventory(defines.inventory.chest)
		}
	elseif entity.name == OUTPUT_CHEST_NAME then
		--add the chests to a lists if these chests so they can be interated over
		global.outputChests[entity.unit_number] = 
		{ 
			entity = entity, 
			inv = entity.get_inventory(defines.inventory.chest),
			filterCount = entity.prototype.filter_count
		}
	elseif entity.name == INPUT_TANK_NAME then
		--add the chests to a lists if these chests so they can be interated over
		global.inputTanks[entity.unit_number] = 
		{
			entity = entity,
			fluidbox = entity.fluidbox
		}
	elseif entity.name == OUTPUT_TANK_NAME then
		--add the chests to a lists if these chests so they can be interated over
		global.outputTanks[entity.unit_number] = 
		{
			entity = entity,
			fluidbox = entity.fluidbox
		}
		entity.active = false
	elseif entity.name == TX_COMBINATOR_NAME then
		global.txControls[entity.unit_number] = entity.get_or_create_control_behavior()
	elseif entity.name == RX_COMBINATOR_NAME then
		global.rxControls[entity.unit_number] = entity.get_or_create_control_behavior()
		entity.operable=false
	elseif entity.name == INV_COMBINATOR_NAME then
		global.invControls[entity.unit_number] = entity.get_or_create_control_behavior()
		entity.operable=false
	elseif entity.name == INPUT_ELECTRICITY_NAME then
		global.inputElectricity[entity.unit_number] = entity
	elseif entity.name == OUTPUT_ELECTRICITY_NAME then
		global.outputElectricity[entity.unit_number] = 
		{
			entity = entity,
			bufferSize = entity.electric_buffer_size
		}
	end
end

function OnKilledEntity(event)
	local entity = event.entity
	if entity.type ~= "entity-ghost" then
		--remove the entities from the tables as they are dead
		if entity.name == INPUT_CHEST_NAME then
			global.inputChests[entity.unit_number] = nil
		elseif entity.name == OUTPUT_CHEST_NAME then
			global.outputChests[entity.unit_number] = nil
		elseif entity.name == INPUT_TANK_NAME then
			global.inputTanks[entity.unit_number] = nil
		elseif entity.name == OUTPUT_TANK_NAME then
			global.outputTanks[entity.unit_number] = nil
		elseif entity.name == TX_COMBINATOR_NAME then
			global.txControls[entity.unit_number] = nil
		elseif entity.name == RX_COMBINATOR_NAME then
			global.rxControls[entity.unit_number] = nil
		elseif entity.name == INV_COMBINATOR_NAME then
			global.invControls[entity.unit_number] = nil
		elseif entity.name == INPUT_ELECTRICITY_NAME then
			global.inputElectricity[entity.unit_number] = nil
		elseif entity.name == OUTPUT_ELECTRICITY_NAME then
			global.outputElectricity[entity.unit_number] = nil
		end
	end
end


-----------------------------
--[[Thing creation events]]--
----------------------------- 
script.on_event(defines.events.on_built_entity, function(event)
	OnBuiltEntity(event)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	OnBuiltEntity(event)
end)


----------------------------
--[[Thing killing events]]--
---------------------------- 
script.on_event(defines.events.on_entity_died, function(event)
	OnKilledEntity(event)
end)

script.on_event(defines.events.on_robot_pre_mined, function(event)
	OnKilledEntity(event)
end)

script.on_event(defines.events.on_pre_player_mined_item, function(event)
	OnKilledEntity(event)
end)


------------------------------
--[[Thing resetting events]]--
------------------------------ 
script.on_init(function()
	Reset()
end)

script.on_configuration_changed(function(data)
	if data.mod_changes and data.mod_changes["clusterio"] then
		Reset()
	end
end)

function Reset()
	global.ticksSinceMasterPinged = 601
	global.isConnected = false
	global.prevIsConnected = false
	global.allowedToMakeElectricityRequests = false
	global.workTick = 0

	if global.config == nil then 
		global.config = 
		{
			BWitems = {},
			item_is_whitelist = false,
			BWfluids = {},
			fluid_is_whitelist = false,
			PlacableArea = 200
		}
	end
	if global.invdata == nil then 
		global.invdata = {} 
	end
	
	global.outputList = {}
	global.inputList = {}
	global.itemStorage = {}
	global.useableItemStorage = {}

	global.inputChestsData = 
	{
		entitiesData = CreateDoublyLinkedList()
	}
	global.outputChestsData = 
	{
		entitiesData = CreateDoublyLinkedList(),
		requests = {},
		requestsLL = nil
	}

	global.inputTanksData = 
	{
		entitiesData = CreateDoublyLinkedList()
	}
	global.outputTanksData = 
	{
		entitiesData = CreateDoublyLinkedList(),
		requests = {},
		requestsLL = nil
	}
	
	global.inputElectricityData = 
	{
		entitiesData = CreateDoublyLinkedList()
	}
	global.outputElectricityData = 
	{
		entitiesData = CreateDoublyLinkedList(),
		requests = {},
		requestsLL = nil
	}
	global.lastElectricityUpdate = 0
	global.maxElectricity = 100000000000000 / ELECTRICITY_RATIO --100TJ assuming a ratio of 1.000.000

	global.rxControls = {}
	global.txControls = {}
	global.invControls = {}

	AddAllEntitiesOfNames(
	{
		INPUT_CHEST_NAME,
		OUTPUT_CHEST_NAME,
		INPUT_TANK_NAME,
		OUTPUT_TANK_NAME,
		RX_COMBINATOR_NAME,
		TX_COMBINATOR_NAME,
		INV_COMBINATOR_NAME,
		INPUT_ELECTRICITY_NAME,
		OUTPUT_ELECTRICITY_NAME
	})
end

script.on_event(defines.events.on_tick, function(event)
	-- TX Combinators must run every tick to catch single pulses
	HandleTXCombinators()
	
	global.ticksSinceMasterPinged = global.ticksSinceMasterPinged + 1
	if global.ticksSinceMasterPinged < 300 then		
		global.isConnected = true
		if global.prevIsConnected == false then
			global.workTick = 0
		end
	
		if global.workTick == 0 then
			--importing electricity should be limited because it requests so
			--much at once. If it wasn't limited then the electricity could
			--make small burst of requests which requests >10x more than it needs
			--which could temporarily starve other networks.
			--Updating every 4 seconds give two chances to give electricity in
			--the 10 second period.
			local timeSinceLastElectricityUpdate = game.tick - global.lastElectricityUpdate
			global.allowedToMakeElectricityRequests = timeSinceLastElectricityUpdate > 60 * 3.5
		end
		
		
		
		
		
		--need to update creation and removal of entities to support linked list
		
		
		
		
		
		
		
		
		
		
		--First retrieve requests and then fulfill them
		if global.workTick >= 0 and global.workTick < TICKS_TO_COLLECT_REQUESTS then
			if global.workTick == 0 then
				ResetRequestGathererIterators()
			end
			RetrieveGetterRequests(global.allowedToMakeElectricityRequests)
		elseif global.workTick >= TICKS_TO_COLLECT_REQUESTS and global.workTick < TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS then
			if global.workTick == TICKS_TO_COLLECT_REQUESTS then
				PrepareToFulfillRequests()
				ResetFulfillRequestIterators()
				UpdateUseableStorage()
			end
			FulfillGetterRequests(global.allowedToMakeElectricityRequests)
		end
		
		--Emptying putters will continiously happen
		--while requests are gathered and fulfilled
		if global.workTick >= 0 and global.workTick < TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS then
			if global.workTick == 0 then
				ResetPutterIterators()
			end
			EmptyPutters()
		end
		
		if     global.workTick == TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS + 0 then
			ExportInputList()
		elseif global.workTick == TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS + 1 then
			ExportOutputList()
		elseif global.workTick == TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS + 2 then
			ExportFluidFlows()
		elseif global.workTick == TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS + 3 then
			ExportItemFlows()
			
			--Restart loop
			global.workTick = 0
			if global.allowedToMakeElectricityRequests then
				global.lastElectricityUpdate = game.tick
			end
		end
	else
		global.isConnected = false
	end
	gobal.prevIsConnected = isConnected

	-- RX Combinators are set and then cleared on sequential ticks to create pulses
	UpdateRXCombinators()
end)

function UpdateUseableStorage()
	for k, v in ipairs(global.itemStorage) do
		GiveItemsToUseableStorage(k, v)
	end
	global.itemStorage = {}
end


----------------------------------------
--[[Getter and setter update methods]]--
---------------------------------------- 
function ResetRequestGathererIterators()
	global.outputChestsData.entitiesData     .RestartIterator(TICKS_TO_COLLECT_REQUESTS)
	global.outputTanksData.entitiesData      .RestartIterator(TICKS_TO_COLLECT_REQUESTS)
	global.outputElectricityData.entitiesData.RestartIterator(TICKS_TO_COLLECT_REQUESTS)
end

function ResetFulfillRequestIterators()
	global.outputChestsData.requestsLL     .RestartIterator(TICKS_TO_FULFILL_REQUESTS)
	global.outputTanksData.requestsLL      .RestartIterator(TICKS_TO_FULFILL_REQUESTS)
	global.outputElectricityData.requestsLL.RestartIterator(TICKS_TO_FULFILL_REQUESTS)
end

function ResetPutterIterators()
	global.inputChestsData.entitiesData     .RestartIterator(TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS)
	global.inputTanksData.entitiesData      .RestartIterator(TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS)
	global.inputElectricityData.entitiesData.RestartIterator(TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS)
end

function PrepareToFulfillRequests()
	global.outputChestsData.requestsLL      = ArrayToLinkedListOfRequests(global.outputChestsData.requests     , true)
	global.outputTanksData.requestsLL       = ArrayToLinkedListOfRequests(global.outputTanksData.requests      , false)
	global.outputElectricityData.requestsLL = ArrayToLinkedListOfRequests(global.outputElectricityData.requests, false)
end

function RetrieveGetterRequests(allowedToGetElectricityRequests)	
	local chestLL = global.outputChestsData.entitiesData
	for i = 1, chestLL.iterator.linksPerTick do
		local nextLink = chestLL.NextLink()
		if nextLink ~= nil then
			GetOutputChestRequest(nextLink.data)
		end
	end
	
	local tankLL = global.outputTanksData.entitiesData
	for i = 1, tankLL.iterator.linksPerTick do
		local nextLink = tankLL.NextLink()
		if nextLink ~= nil then
			GetOutputTankRequest(nextLink.data)
		end
	end
	
	if allowedToGetElectricityRequests then
		local electricityLL = global.outputElectricityData.entitiesData
		for i = 1, electricityLL.iterator.linksPerTick do
			local nextLink = electricityLL.NextLink()
			if nextLink ~= nil then
				GetOutputElectricityRequest(nextLink.data)
			end
		end
	end
end

function FulfillGetterRequests(allowedToGetElectricityRequests)
	local chestLL = global.outputChestsData.requestsLL
	for i = 1, chestLL.iterator.linksPerTick do
		local nextLink = chestLL.NextLink()
		if nextLink ~= nil then
			FulfillOutputChestRequest(nextLink.data)
		end
	end
	
	local tankLL = global.outputTanksData.requestsLL
	for i = 1, tankLL.iterator.linksPerTick do
		local nextLink = tankLL.NextLink()
		if nextLink ~= nil then
			FulfillOutputTankRequest(nextLink.data)
		end
	end
	
	if allowedToGetElectricityRequests then
		local electricityLL = global.outputElectricityData.requestsLL
		for i = 1, electricityLL.iterator.linksPerTick do
			local nextLink = electricityLL.NextLink()
			if nextLink ~= nil then
				FulfillOutputElectricityRequest(nextLink.data)
			end
		end
	end
end

function EmptyPutters()
	local chestLL = global.inputChestsData.entitiesData
	for i = 1, chestLL.iterator.linksPerTick do
		local nextLink = chestLL.NextLink()
		if nextLink ~= nil then
			HandleInputChest(nextLink.data)
		end
	end
	
	local tankLL = global.inputTanksData.entitiesData
	for i = 1, tankLL.iterator.linksPerTick do
		local nextLink = tankLL.NextLink()
		if nextLink ~= nil then
			HandleInputTank(nextLink.data)
		end
	end
	
	local electricityLL = global.inputElectricityData.entitiesData
	for i = 1, electricityLL.iterator.linksPerTick do
		local nextLink = electricityLL.NextLink()
		if nextLink ~= nil then
			HandleInputElectricity(nextLink.data)
		end
	end
end


function HandleInputChest(entityData)
	local entity = entityData.entity
	local inventory = entityData.inv
	if entity.valid then
		--get the content of the chest
		local items = inventory.get_contents()
		--write everything to the file
		for itemName, itemCount in pairs(items) do
			if isItemLegal(itemName) then
				AddItemToInputList(itemName, itemCount)
				inventory.remove({name = itemName, count = itemCount})
			end
		end
	end
end

function HandleInputTank(entityData)
	local entity  = entityData.entity
	local fluidbox = entityData.fluidbox
	if entity.valid then
		--get the content of the chest
		local fluid = fluidbox[1]
		if fluid ~= nil and math.floor(fluid.amount) > 0 then
			if isFluidLegal(fluid.name) then
				AddItemToInputList(fluid.name, math.floor(fluid.amount))
				fluid.amount = fluid.amount - math.floor(fluid.amount)
			end
		end
		fluidbox[1] = fluid
	end
end

function HandleInputElectricity(entity)
	--if there is too much energy in the network then stop outputting more
	if global.invdata and global.invdata[ELECTRICITY_ITEM_NAME] and global.invdata[ELECTRICITY_ITEM_NAME] >= global.maxElectricity then
		return
	end
	
	if entity.valid then
		local energy = entity.energy
		local availableEnergy = math.floor(energy / ELECTRICITY_RATIO)
		if availableEnergy > 0 then
			AddItemToInputList(ELECTRICITY_ITEM_NAME, availableEnergy)
			entity.energy = energy - (availableEnergy * ELECTRICITY_RATIO)
		end
	end
end


function GetOutputChestRequest(requests, entityData)
	local entity = entityData.entity
	local chestInventory = entityData.inv
	local filterCount = entityData.filterCount
	--Don't insert items into the chest if it's being deconstructed
	--as that just leads to unnecessary bot work
	if entity.valid and not entity.to_be_deconstructed(entity.force) then
		--Go though each request slot
		for i = 1, filterCount do
			local requestItem = entity.get_request_slot(i)
			
			--Some request slots may be empty and some items are not allowed
			--to be imported
			if requestItem ~= nil and isItemLegal(requestItem.name) then
				local itemsInChest = chestInventory.get_item_count(requestItem.name)
				
				--If there isn't enough items in the chest
				if itemsInChest < requestItem.count then
					local missingAmount = requestItem.count - itemsInChest
					local entry = AddRequestToTable(requests, requestItem.name, missingAmount, entity)
					entry.inv = chestInventory
				end
			end
		end
	end
end

function GetOutputTankRequest(requests, entityData)
	local entity = entityData.entity
	local fluidbox = entityData.fluidbox
	--The type of fluid the tank should output
	--is determined by the recipe set in the  entity.
	--If no recipe is set then it shouldn't output anything
	local recipe = entity.get_recipe()
	if entity.valid and recipe ~= nil then
		--Get name of the fluid to output
		local fluidName = recipe.products[1].name
		--Some fluids may be illegal. If that's the case then don't process them
		if isFluidLegal(fluidName) then
			--Either get the current fluid or reset it to the requested fluid
			local fluid = fluidbox[1] or {name = fluidName, amount = 0}

			--If the current fluid isn't the correct fluid
			--then remove that fluid
			if fluid.name ~= fluidName then
				fluid = {name = fluidName, amount = 0}
			end

			local missingFluid = math.max(math.ceil(MAX_FLUID_AMOUNT - fluid.amount), 0)
			--If the entity is missing fluid than add a request for fluid
			if missingFluid > 0 then
				local entry = AddRequestToTable(requests, fluidName, missingFluid, entity)
				--Add fluid to the request so it doesn't have to be created again
				entry.fluid = fluid
				entry.fluidbox = fluidbox
			end
		end
	end
end

function GetOutputElectricityRequest(requests, entityData)
	local entity = entityData.entity
	local bufferSize = entityData.bufferSize
	if entity.valid then
		local energy = entity.energy
		local missingElectricity = math.floor((bufferSize - energy) / ELECTRICITY_RATIO)
		if missingElectricity > 0 then
			local entry = AddRequestToTable(requests, ELECTRICITY_ITEM_NAME, missingElectricity, entity)
			entry.energy = energy
		end
	end
end


function FulfillOutputChestRequest(requests)
	EvenlyDistributeItems(requests, true, OutputChestInputMethod)
end

function FulfillOutputTankRequest(requests)
	EvenlyDistributeItems(requests, false, OutputTankInputMethod)
end

function FulfillOutputElectricityRequest(requests)
	EvenlyDistributeItems(requests, false, OutputElectricityinputMethod)
end


function OutputChestInputMethod(request, itemName, evenShareOfItems)
	if request.storage.valid then
		local itemsToInsert = 
		{
			name = itemName, 
			count = evenShareOfItems
		}
		
		return request.inv.insert(itemsToInsert)
	else
		return 0
	end
end

function OutputTankInputMethod(request, _, evenShareOfFluid)
	if request.storage.valid then
		request.fluid.amount = request.fluid.amount + evenShareOfFluid
		
		--Need to set steams heat because otherwise it's too low
		if request.fluid.name == "steam" then
			request.fluid.temperature = 165
		end
		
		request.fluidbox[1] = request.fluid
		return evenShareOfFluid
	else
		return 0
	end
end

function OutputElectricityinputMethod(request, _, evenShare)
	if request.storage.valid then
		request.storage.energy = request.energy + (evenShare * ELECTRICITY_RATIO)
		return evenShare
	else
		return 0
	end
end


function ArrayToLinkedListOfRequests(array, shouldSort)
	local linkedList = CreateDoublyLinkedList()
	for itemName, requestInfo in ipairs(array) do
		if shouldSort then
			--To be able to distribute it fairly, the requesters need to be sorted in order of how
			--much they are missing, so the requester with the least missing of the item will be first.
			--If this isn't done then there could be items leftover after they have been distributed
			--even though they could all have been distributed if they had been distributed in order.
			table.sort(requestInfo.requesters, function(left, right)
				return left.missingAmount < right.missingAmount
			end)
		end
		
		for i = 1, #requestInfo.requesters do
			local request = requestInfo.requesters[i]
			request.itemName = itemName
			request.requestedAmount = requestInfo.requestedAmount
			linkedList.AddLink(request, 0)
		end
	end
	
	return linkedList
end

function AddRequestToTable(requests, itemName, missingAmount, storage)
	--If this is the first entry for this item type then
	--create a table for this item type first
	if requests[itemName] == nil then
		requests[itemName] = 
		{
			requestedAmount = 0,
			requesters = {}
		}
	end
	
	local itemEntry = requests[itemName]
	
	--Add missing item to the count and add this chest inv to the list
	itemEntry.requestedAmount = itemEntry.requestedAmount + missingAmount
	itemEntry.requesters[#itemEntry.requesters + 1] = 
	{
		storage = storage,
		missingAmount = missingAmount
	}
	
	return itemEntry.requesters[#itemEntry.requesters]
end

function EvenlyDistributeItems(request, functionToAddItems)
	--Take the required item count from storage or how much storage has
	local itemCount = RequestItemsFromUseableStorage(itemName, request.requestedAmount)
	
	if itemCount < request.requestedAmount then
		--Missing items items of this type so request them
		local missingItems = request.requestedAmount - itemCount
		AddItemToOutputList(itemName, missingItems)
	end
	
	--If there isn't enough items to fill all the requests, then the  requests
	--has to be scaled down in proportion to how much that is missing so all
	--requests will be filled equally much
	local itemsToMissingItemsRatio = itemCount / request.requestedAmount
	
	--If storage had some of the required item then begin distributing it evenly
	--in all the requesters
	if itemCount > 0 then			
		local chestHold = math.ceil(request.missingAmount * itemsToMissingItemsRatio)
			
		--No need to insert 0 of something
		if chestHold > 0 then
			--Insert the missing items into the entity and subtract the inserted items from the itemCount
			local insertedItemsCount = functionToAddItems(request, itemName, chestHold)
			itemCount = itemCount - insertedItemsCount
		end
		
		--Give remaining items back to storage
		if itemCount > 0 then
			GiveItemsToUseableStorage(itemName, itemCount)
		end
	end

end


-----------------------------------
--[[Methods that write to files]]--
----------------------------------- 
function ExportInputList()
	local exportStrings = {}
	for k,v in pairs(global.inputList) do
		exportStrings[#exportStrings + 1] = k.." "..v.."\n"
	end
	global.inputList = {}
	if #exportStrings > 0 then

		--only write to file once as i/o is slow
		--it's much faster to concatenate all the lines with table.concat
		--instead of doing it with the .. operator
		game.write_file(OUTPUT_FILE, table.concat(exportStrings), true, global.write_file_player or 0)
	end
end

function ExportOutputList()
	local exportStrings = {}
	for k,v in pairs(global.outputList) do
		exportStrings[#exportStrings + 1] = k.." "..v.."\n"
	end
	global.outputList = {}
	if #exportStrings > 0 then

		--only write to file once as i/o is slow
		--it's much faster to concatenate all the lines with table.concat
		--instead of doing it with the .. operator
		game.write_file(ORDER_FILE, table.concat(exportStrings), true, global.write_file_player or 0)
	end
end

function ExportItemFlows()
	local flowreport = {type="item",flows={}}

	for _,force in pairs(game.forces) do
		flowreport.flows[force.name] = {
			input_counts = force.item_production_statistics.input_counts,
			output_counts = force.item_production_statistics.output_counts,
		}
	end

	game.write_file(FLOWS_FILE, json:encode(flowreport).."\n", true, global.write_file_player or 0)
end

function ExportFluidFlows()
	local flowreport = {type="fluid",flows={}}

	for _,force in pairs(game.forces) do
		flowreport.flows[force.name] = {
			input_counts = force.fluid_production_statistics.input_counts,
			output_counts = force.fluid_production_statistics.output_counts,
		}
	end

	game.write_file(FLOWS_FILE, json:encode(flowreport).."\n", true, global.write_file_player or 0)
end


---------------------------------
--[[Update combinator methods]]--
--------------------------------- 
function AddFrameToRXBuffer(frame)
	-- Add a frame to the buffer. return remaining space in buffer
	local validsignals = {
		["virtual"] = game.virtual_signal_prototypes,
		["fluid"]	 = game.fluid_prototypes,
		["item"]		= game.item_prototypes
	}

	global.rxBuffer = global.rxBuffer or {}

	-- if buffer is full, drop frame
	if #global.rxBuffer >= MAX_RX_BUFFER_SIZE then return 0 end

	-- frame = {{count=42,name="signal-grey",type="virtual"},{...},...}
	local signals = {}
	local index = 1

	for _,signal in pairs(frame) do
		if validsignals[signal.type] and validsignals[signal.type][signal.name] then
			signals[index] =
				{
					index=index,
					count=signal.count,
					signal={ name=signal.name, type=signal.type }
				}
			index = index + 1
			--TODO: break if too many?
			--TODO: error token on mismatched signals? maybe mismatch1-n signals?
		end
	end

	if index > 1 then table.insert(global.rxBuffer,signals) end

	return MAX_RX_BUFFER_SIZE - #global.rxBuffer
end

function HandleTXCombinators()
	-- Check all TX Combinators, and if condition satisfied, add frame to transmit buffer

	-- frame = {{count=42,name="signal-grey",type="virtual"},{...},...}
	local signals = {["item"]={},["virtual"]={},["fluid"]={}}
	for i,txControl in pairs(global.txControls) do
		if txControl.valid then
			local frame = txControl.signals_last_tick
			if frame then
				for _,signal in pairs(frame) do
					signals[signal.signal.type][signal.signal.name]=
						(signals[signal.signal.type][signal.signal.name] or 0) + signal.count
				end
			end
		end
	end

	local frame = {}
	for type,arr in pairs(signals) do
		for name,count in pairs(arr) do
			table.insert(frame,{count=count,name=name,type=type})
		end
	end

	if #frame > 0 then
		if global.worldID then
			table.insert(frame,1,{count=global.worldID,name="signal-srcid",type="virtual"})
		end
		table.insert(frame,{count=game.tick,name="signal-srctick",type="virtual"})
		game.write_file(TX_BUFFER_FILE, json:encode(frame).."\n", true, global.write_file_player or 0)

		-- Loopback for testing
		--AddFrameToRXBuffer(frame)

	end
end

function UpdateRXCombinators()
	-- if the RX buffer is not empty, get a frame from it and output on all RX Combinators
	if global.rxBuffer and #global.rxBuffer > 0 then
		local frame = table.remove(global.rxBuffer)
		for i,rxControl in pairs(global.rxControls) do
			if rxControl.valid then
				rxControl.parameters={parameters=frame}
				rxControl.enabled=true
			end
		end
  else
    -- no frames to send right now, blank all...
    for i,rxControl in pairs(global.rxControls) do
  		if rxControl.valid then
  			rxControl.enabled=false
  		end
  	end
	end
end

function UpdateInvCombinators()
	-- Update all inventory Combinators
	-- Prepare a frame from the last inventory report, plus any virtuals
	local invframe = {}
	if global.worldID then
		table.insert(invframe,{count=global.worldID,index=#invframe+1,signal={name="signal-localid",type="virtual"}})
	end

	local items = game.item_prototypes
	local fluids = game.fluid_prototypes
	local virtuals = game.virtual_signal_prototypes
	if global.invdata then
		for name,count in pairs(global.invdata) do
			if virtuals[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="virtual"}}
			elseif fluids[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="fluid"}}
			elseif items[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="item"}}
			end
		end
	end

	for i,invControl in pairs(global.invControls) do
		if invControl.valid then
			invControl.parameters={parameters=invframe}
			invControl.enabled=true
		end
	end

end


---------------------
--[[Remote things]]--
--------------------- 
remote.add_interface("clusterio",
{
	runcode=function(codeToRun) loadstring(codeToRun)() end,
	import = function(itemName, itemCount)
		GiveItemsToStorage(itemName, itemCount)
	end,
	importMany = function(jsonString)
		local items = json:decode(jsonString)
		for k, item in pairs(items) do
			for itemName, itemCount in pairs(item) do
				GiveItemsToStorage(itemName, itemCount)
			end
		end
	end,
	printStorage = function()
		local items = ""
		for itemName, itemCount in pairs(global.itemStorage) do
			items = items.."\n"..itemName..": "..tostring(itemCount)
		end
		game.print(items)
	end,
	reset = Reset,
	receiveFrame = function(jsonframe)
		local frame = json:decode(jsonframe)
		-- frame = {tick=123456,frame={{count=42,name="signal-grey",type="virtual"},{...},...}}
		return AddFrameToRXBuffer(frame)
	end,
	receiveMany = function(jsonframes)
		local frames = json:decode(jsonframes)
		local buffer
		for _,frame in pairs(frames) do
			buffer = AddFrameToRXBuffer(frame)
			if buffer==0 then return 0 end
		end
		return buffer
	end,
	setFilePlayer = function(i)
		global.write_file_player = i
	end,
	receiveInventory = function(jsoninvdata)
		global.ticksSinceMasterPinged = 0
		local invdata = json:decode(jsoninvdata)
		for name,count in pairs(invdata) do
			global.invdata[name]=count	
		end
		-- invdata = {["iron-plates"]=1234,["copper-plates"]=5678,...}
		UpdateInvCombinators()
	end,
	setWorldID = function(newid)
		global.worldID = newid
		UpdateInvCombinators()
	end
})

commands.add_command("ccri", "clusterio internal command, receive Inventory", function(event) 
	if game.player then 
		return 
	end 
	local cmd = event.parameter 
	cmd = "for name,count in pairs(" + cmd + ") do global.invdata[name] = count end" 
	loadstring(cmd)()
end)

commands.add_command("ccrm", "clusterio internal command, receive Many", function(event) 
	if game.player then 
		return 
	end 
	local cmd = event.parameter 
	cmd = "for k,item in pairs(" + cmd + ") do GiveItemsToStorage(k, item) end" 
	loadstring(cmd)() 
end)


--------------------
--[[Misc methods]]--
-------------------- 
function RequestItemsFromUseableStorage(itemName, itemCount)
	--if result is nil then there is no items in storage
	--which means that no items can be given
	if global.useableItemStorage[itemName] == nil then
		return 0
	end
	--if the number of items in storage is lower than the number of items
	--requested then take the number of items there are left otherwise take the requested amount
	local itemsTakenFromStorage = math.min(global.useableItemStorage[itemName], itemCount)
	global.useableItemStorage[itemName] = global.useableItemStorage[itemName] - itemsTakenFromStorage

	return itemsTakenFromStorage
end

function GiveItemsToUseableStorage(itemName, itemCount)
	--if this is called for the first time for an item then the result
	--is nil. if that's the case then set the result to 0 so it can
	--be used in arithmetic operations
	global.useableItemStorage[itemName] = global.useableItemStorage[itemName] or 0
	global.useableItemStorage[itemName] = global.useableItemStorage[itemName] + itemCount
end

function GiveItemsToStorage(itemName, itemCount)
	--if this is called for the first time for an item then the result
	--is nil. if that's the case then set the result to 0 so it can
	--be used in arithmetic operations
	global.itemStorage[itemName] = global.itemStorage[itemName] or 0
	global.itemStorage[itemName] = global.itemStorage[itemName] + itemCount
end

function AddItemToInputList(itemName, itemCount)
	global.inputList[itemName] = (global.inputList[itemName] or 0) + itemCount
end

function AddItemToOutputList(itemName, itemCount)
	global.outputList[itemName] = (global.outputList[itemName] or 0) + itemCount
end

function isFluidLegal(name)
	for _,itemName in pairs(global.config.BWfluids) do
		if itemName==name then
			return global.config.fluid_is_whitelist
		end
	end
	return not global.config.fluid_is_whitelist
end

function isItemLegal(name)
	for _,itemName in pairs(global.config.BWitems) do
		if itemName==name then
			return global.config.item_is_whitelist
		end
	end
	return not global.config.item_is_whitelist
end


-------------------
--[[GUI methods]]--
------------------- 
function createElemGui_INTERNAL(pane,guiName,elem_type,loadingList)
	local gui = pane.add{ type = "table", name = guiName, column_count = 5 }
	for _,item in pairs(loadingList) do
		gui.add{type="choose-elem-button",elem_type=elem_type,item=item,fluid=item}
	end
	gui.add{type="choose-elem-button",elem_type=elem_type}
end

function toggleBWItemListGui(parent)
	if parent["clusterio-black-white-item-list-config"] then
        parent["clusterio-black-white-item-list-config"].destroy()
        return
    end
	local pane=parent.add{type="frame", name="clusterio-black-white-item-list-config", direction="vertical"}
	pane.add{type="label",caption="Item"}
	pane.add{type="checkbox", name="clusterio-is-item-whitelist", caption="whitelist",state=global.config.item_is_whitelist}
	createElemGui_INTERNAL(pane,"item-black-white-list","item",global.config.BWitems)
end

function toggleBWFluidListGui(parent)
	if parent["clusterio-black-white-fluid-list-config"] then
        parent["clusterio-black-white-fluid-list-config"].destroy()
        return
    end
	local pane=parent.add{type="frame", name="clusterio-black-white-fluid-list-config", direction="vertical"}
	pane.add{type="label",caption="Fluid"}
	pane.add{type="checkbox", name="clusterio-is-fluid-whitelist", caption="whitelist",state=global.config.fluid_is_whitelist}
	createElemGui_INTERNAL(pane,"fluid-black-white-list","fluid",global.config.BWfluids)
end

function processElemGui(event,toUpdateConfigName)--VERY WIP
	parent=event.element.parent
	if event.element.elem_value==nil then event.element.destroy()
	else parent.add{type="choose-elem-button",elem_type=parent.children[1].elem_type} end
	global.config[toUpdateConfigName]={}
	for _,guiElement in pairs(parent.children) do
		if guiElement.elem_value~=nil then
			table.insert(global.config[toUpdateConfigName],guiElement.elem_value)
		end
	end
end

script.on_event(defines.events.on_gui_value_changed,function(event) 
	if event.element.name=="clusterio-Placing-Bounding-Box" then 
		global.config.PlacableArea=event.element.slider_value 
		event.element.parent["clusterio-Placing-Bounding-Box-Label"].caption="Chest/fluid bounding box: "..global.config.PlacableArea
	end 
end)

function toggleMainConfigGui(parent)
	if parent["clusterio-main-config-gui"] then
        parent["clusterio-main-config-gui"].destroy()
        return
    end
	local pane = parent.add{type="frame", name="clusterio-main-config-gui", direction="vertical"}
	pane.add{type="button", name="clusterio-Item-WB-list", caption="Item White/Black list"}
    pane.add{type="button", name="clusterio-Fluid-WB-list", caption="Fluid White/Black list"}
	pane.add{type="label", caption="Chest/fluid bounding box: "..global.config.PlacableArea,name="clusterio-Placing-Bounding-Box-Label"}
	pane.add{type="slider", name="clusterio-Placing-Bounding-Box",minimum_value=0,maximum_value=800,value=global.config.PlacableArea}
	
	--Electricity panel
	local electricityPane = pane.add{type="frame", name="clusterio-main-config-gui", direction="horizontal"}
	electricityPane.add{type="label", name="clusterio-electricity-label", caption="Max electricity"}
	electricityPane.add{type="textfield", name="clusterio-electricity-field", text = global.maxElectricity}
	
end

function processMainConfigGui(event)
	if event.element.name=="clusterio-Item-WB-list" then
		toggleBWItemListGui(game.players[event.player_index].gui.top)
	end
	if event.element.name=="clusterio-Fluid-WB-list" then
		toggleBWFluidListGui(game.players[event.player_index].gui.top)
	end
end

script.on_event(defines.events.on_gui_checked_state_changed, function(event) 
	if not (event.element.parent) then return end
	if event.element.name=="clusterio-is-fluid-whitelist" then 
		global.config.fluid_is_whitelist=event.element.state 
		return
	end
	if event.element.name=="clusterio-is-item-whitelist" then 
		global.config.item_is_whitelist=event.element.state 
		return
	end
end)
	
script.on_event(defines.events.on_gui_click, function(event)
	if not (event.element and event.element.valid) then return end
	if not (event.element.parent) then return end
	local player = game.players[event.player_index]
	if event.element.parent.name=="clusterio-main-config-gui" then processMainConfigGui(event) return end
	if event.element.name=="clusterio-main-config-gui-toggle-button" then toggleMainConfigGui(game.players[event.player_index].gui.top) return end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	if not (event.element and event.element.valid) then return end
	if not (event.element.parent) then return end
	
	if event.element.parent.name=="item-black-white-list" then
		processElemGui(event,"BWitems")
		return
	end
	if event.element.parent.name=="fluid-black-white-list" then
		processElemGui(event,"BWfluids")
		return
	end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
	if not (event.element and event.element.valid) then return end
	
	if event.element.name == "clusterio-electricity-field" then
		local newMax = tonumber(event.element.text)
		if newMax and newMax >= 0 then
			global.maxElectricity = newMax
		end
	end
end)

function makeConfigButton(parent)
	if not parent["clusterio-main-config-gui-button"] then
		local pane = parent.add{type="frame", name="clusterio-main-config-gui-button", direction="vertical"}
		pane.add{type="button", name="clusterio-main-config-gui-toggle-button", caption="config"}
    end
end


--------------------------
--[[Some random events]]--
-------------------------- 
script.on_event(defines.events.on_player_joined_game,function(event) 
	if game.players[event.player_index].admin then  
		makeConfigButton(game.players[event.player_index].gui.top)
	end
end)

script.on_event(defines.events.on_player_died,function(event) 
	--local msg="!shout "..game.players[event.player_index].name.." has been killed"
	--if event.cause~=nil then if event.cause.name~="locomotive" then return end msg=msg.." by "..event.cause.name else msg=msg.."." end
	game.write_file("alerts.txt","player_died, "..game.players[event.player_index].name.." has been killed by "..(event.cause or {name="unknown"}).name,true)
end)
--script.on_load(function() commands.add_command("ccri","clusterio internal command",function(x) game.print(x.test) end ) end)
