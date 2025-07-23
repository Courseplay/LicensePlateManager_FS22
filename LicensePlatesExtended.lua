LicensePlateStorage = {
	data = {},
	dataByVehicle = {},
	debugActive = true,
	MOD_NAME = g_currentModName,
	BASE_DIRECTORY = g_currentModDirectory,
	areDuplicatesAllowed = false,
	baseXmlKey = "LicensePlateManager",
	allowDuplicatesText = g_i18n:getText("LPT_allowDuplicates"),
	disallowDuplicatesText = g_i18n:getText("LPT_disallowDuplicates"),
}

function LicensePlateStorage.getText()
	return LicensePlateStorage.areDuplicatesAllowed and LicensePlateStorage.allowDuplicatesText or LicensePlateStorage.disallowDuplicatesText
end

function LicensePlateStorage.debug(str, ...)
	if LicensePlateStorage.debugActive then
		print(string.format("LTS: "..str, ...))
	end
end

function LicensePlateStorage.enableLicensePlateDuplicates(_,enable)
	if enable == "true" then 
		LicensePlateStorage.areDuplicatesAllowed = true
	else 
		LicensePlateStorage.areDuplicatesAllowed = false
	end
	LicensePlateStorage.debug("Duplicates are %s", tostring(LicensePlateStorage.areDuplicatesAllowed))
end

-- --- Adds the license plate str to a global table.
-- local function setLicensePlatesData(vehicle, licensePlateData, ...)
-- 	if vehicle:getHasLicensePlates() and vehicle.propertyState ~= Vehicle.PROPERTY_STATE_SHOP_CONFIG then
-- 		if licensePlateData and licensePlateData.characters then 
-- 			local chars = table.concat(licensePlateData.characters)
-- 			if chars then 
-- 				LicensePlateStorage.debug("found license plate data (%s) for %s(%s)", 
-- 					chars,  vehicle:getName(), vehicle.rootVehicle:getName())
-- 				if LicensePlateStorage.data[chars] == nil then 
-- 					LicensePlateStorage.data[chars] = {}
-- 				end
-- 				LicensePlateStorage.data[chars][vehicle] = vehicle				
-- 				local spec = vehicle.spec_licensePlates

-- 				if spec.lpsOldLicensePlateData and spec.lpsOldLicensePlateData.characters then 
-- 					local chars = table.concat(spec.lpsOldLicensePlateData.characters)
-- 					if chars then
-- 						LicensePlateStorage.data[chars][vehicle] = nil	
-- 						if next(LicensePlateStorage.data[chars]) == nil then 
-- 							LicensePlateStorage.data[chars] = nil
-- 						end
-- 					end
-- 				end
-- 				spec.lpsOldLicensePlateData = table.clone(licensePlateData, 3)
-- 			end
-- 		end
-- 	end
-- end

-- LicensePlates.setLicensePlatesData = Utils.appendedFunction(LicensePlates.setLicensePlatesData, setLicensePlatesData)

-- --- Removes the license plate str from the global table, as the vehicles was deleted.
-- local function removeLicensePlate(vehicle, ...)
-- 	if vehicle.propertyState ~= Vehicle.PROPERTY_STATE_SHOP_CONFIG then
-- 		local spec = vehicle.spec_licensePlates
-- 		if spec and spec.licensePlateData and spec.licensePlateData.characters then
-- 			local chars = table.concat(spec.licensePlateData.characters)
-- 			LicensePlateStorage.debug("trying to remove %s", tostring(chars))
-- 			if chars and LicensePlateStorage.data[chars] then 
-- 				LicensePlateStorage.data[chars][vehicle] = nil
-- 				if next(LicensePlateStorage.data[chars]) == nil then 
-- 					LicensePlateStorage.data[chars] = nil
-- 				end
-- 				LicensePlateStorage.debug("removed license plate data for %s", vehicle:getName())
-- 			end
-- 		end
-- 	end	
-- end

-- LicensePlates.onDelete = Utils.prependedFunction(LicensePlates.onDelete, removeLicensePlate)

-- --- Checks if the plate str is already given to another vehicle.
function LicensePlateStorage.validatePlates(licensePlateData, curVehicle, storeItem)
	LicensePlateStorage.debug("validatePlates")
	local valid, vehicleFound = true, nil
	local hasLicensePlate = curVehicle and curVehicle:getHasLicensePlates()
	hasLicensePlate = hasLicensePlate or storeItem and storeItem.hasLicensePlates

	if hasLicensePlate and licensePlateData.placementIndex and licensePlateData.placementIndex == LicensePlateManager.PLACEMENT_OPTION.NONE then
		return true
	end

	if hasLicensePlate and licensePlateData.characters ~= nil and not LicensePlateStorage.areDuplicatesAllowed then
		LicensePlateStorage.debug("checking for duplicates")
		local chars = table.concat(licensePlateData.characters)
		if chars then 
			local chars2 = string.gsub(chars, "_", "0") -- for mp ...
			LicensePlateStorage.debug("license plate string found: %s", chars)
			local vehicleTable = LicensePlateStorage.data[chars] or LicensePlateStorage.data[chars2]
			if vehicleTable  then 
				LicensePlateStorage.debug("vehicle table found: %s", chars)
				valid = false  
				vehicleFound = next(vehicleTable)
				if vehicleFound ~= nil and vehicleFound == curVehicle then 
					LicensePlateStorage.debug("vehicle ignored as it's the same! (%s)", curVehicle:getName())
					valid = true
				end
			end
		end
	end
	if not valid then 
		g_gui:showInfoDialog({
			text = string.format(g_i18n:getText("LPT_licensePlateAlreadyUsed"), vehicleFound:getName())
		})
	end
	return valid
end

-- --- Only allow license plate change, if the new plate is not given to another vehicle.
-- local function onChangeLicensePlate(self, superFunc, licensePlateData, ...)
-- 	if not g_licensePlateManager:getAreLicensePlatesAvailable() then 
-- 		return superFunc(self, licensePlateData, ...)
-- 	end
-- 	if licensePlateData == nil or next(licensePlateData) == nil then 
-- 		return superFunc(self, licensePlateData, ...)
-- 	end
	
-- 	local valid = LicensePlateStorage.validatePlates(licensePlateData, self.vehicle, self.storeItem)
-- 	if not valid then 
-- 		return
-- 	end
-- 	return superFunc(self, licensePlateData, ...)
-- end
-- ShopConfigScreen.onChangeLicensePlate = Utils.overwrittenFunction(ShopConfigScreen.onChangeLicensePlate, onChangeLicensePlate)

--- Adds a menu to view all assigned license plates.
local function onOpen(self)
	self.target.sortedPlates = {}
	self.target.sortedVehicles = {}
	for _, v in pairs(g_currentMission.vehicleSystem.vehicles) do
		local str = ""
		local spec = v.spec_licensePlates
		if spec ~= nil then
			if v:getHasLicensePlates() and v.propertyState ~= Vehicle.PROPERTY_STATE_SHOP_CONFIG then
				local licensePlateData = spec.licensePlateData
				if licensePlateData and licensePlateData.characters then 
					str = table.concat(licensePlateData.characters)
					if str then 
						LicensePlateStorage.debug("found license plate data (%s) for %s(%s)", 
							str,  v:getName(), v.rootVehicle:getName())	
						
					end
				end
			end
			if str ~= "" then 
				table.insert(self.target.sortedPlates, 
					LicensePlates.getSpecValuePlateText(nil, v) or str)
				table.insert(self.target.sortedVehicles, v)
			end
		end
	end

	-- --- Sorts the license plate strings.
	-- self.target.data = {}
	-- for str, vehicleTable in pairs(LicensePlateStorage.data) do 
	-- 	for _, v in pairs(vehicleTable) do
	-- 		str = LicensePlates.getSpecValuePlateText(nil, v) or str
	-- 		table.insert(self.target.sortedPlates, str)
	-- 		if self.target.data[str] == nil then 
	-- 			self.target.data[str] = {}
	-- 		end
	-- 		table.insert(self.target.data[str], v)
	-- 	end
	-- end
	-- table.sort(self.target.sortedPlates)
	-- for _, str in ipairs(self.target.sortedPlates) do 
	-- 	for _,v in ipairs(self.target.data[str]) do 
	-- 		table.insert(self.target.sortedVehicles, v)
	-- 	end
	-- end
	
	if not self.tpsInitialized then 
		--- Functions needed for the smooth list.
		self.target.getNumberOfItemsInSection =  function (self, list, section)
			return #self.sortedPlates or #self.target.sortedPlates
		end

		self.target.populateCellForItemInSection = function (self, list, section, index, cell)
			local plate = self.sortedPlates[index]
			local vehicle = self.sortedVehicles[index]
			if vehicle.rootVehicle:getName() ~= vehicle:getName() then
				cell:getAttribute("vehicle"):setText(vehicle.rootVehicle:getName())
				cell:getAttribute("implement"):setText(vehicle:getName())
			else
				cell:getAttribute("vehicle"):setText(vehicle:getName())
				cell:getAttribute("implement"):setText("")
			end
			cell:getAttribute("licensePlate"):setText(plate)
			-- if #self.data[plate] > 1 and not LicensePlateStorage.areDuplicatesAllowed then 
			-- 	cell:setDisabled(true)
			-- else 
			-- 	cell:setDisabled(false)
			-- end
		end
		
		self.target.onListSelectionChanged = function(self, list, section, index)
		
		end
		self.target.getNumberOfSections = function(self)
			return 1
		end
		
		-- self.target.getTitleForSectionHeader = function(self)
		-- 	return ""
		-- end

		self.target.onClickAllowDuplicates = function(self, btn)
			LicensePlateStorage.areDuplicatesAllowed = not LicensePlateStorage.areDuplicatesAllowed
			LicensePlateStorage.debug("onClickAllowDuplicates")
			btn:setText(LicensePlateStorage.getText())
			self.licensePlateList:reloadData()

			local xmlFile = XMLFile.create("temp",  LicensePlateStorage.xmlFileName, LicensePlateStorage.baseXmlKey, LicensePlateStorage.xmlSchema)
			if xmlFile then
				xmlFile:setValue(LicensePlateStorage.baseXmlKey .. "#areDuplicatesAllowed", LicensePlateStorage.areDuplicatesAllowed)
				xmlFile:save()
				xmlFile:delete()
			end
		end
		
		--- Adds the additional menu.
		LicensePlateStorage.debug("self.tpsInitialized")
		g_gui:loadProfiles( Utils.getFilename("gui/guiProfiles.xml", LicensePlateStorage.BASE_DIRECTORY) )

		local xmlFile = loadXMLFile("Temp", Utils.getFilename("gui/AssignedLicensePlates.xml", LicensePlateStorage.BASE_DIRECTORY))
		g_gui:loadGuiRec(xmlFile, "AssignedLicensePlatesLayout", self, self.target)		
		delete(xmlFile)
		--- Setup for the list and the additional gui elements.
		self.target:exposeControlsAsFields()
		self.tpsInitialized = true
		self.target.licensePlateList:setDataSource(self.target)
	  	self.target.licensePlateList:setDelegate(self.target)
		self.target:onGuiSetupFinished()
		self:updateAbsolutePosition()

	-- 	self.target.allDuplicatesBtn:unlinkElement()
	-- 	FocusManager:removeElement(self.target.allDuplicatesBtn)
	-- 	self.target.okButton.parent:addElement(self.target.allDuplicatesBtn)
	-- 	self.target.okButton.parent:invalidateLayout()
	-- 	self.target.allDuplicatesBtn:setText(LicensePlateStorage.getText())
	end
	self.target.licensePlateList:reloadData()
end

local function onLoadMapFinished(configScreen, ...)
	--- Only allow buying, if the license plate is not given to another vehicle.
	local function onClick(self, superFunc, ...)
		if not g_licensePlateManager:getAreLicensePlatesAvailable()  then 
			return superFunc(self, ...)
		end
		LicensePlateStorage.debug("onClick")
		if self.licensePlateData then 
			local valid = LicensePlateStorage.validatePlates(self.licensePlateData, self.vehicle, self.storeItem)
			if not valid then 
				return
			end
		end
		return superFunc(self, ...)
	end
	configScreen.buyButton.onClickCallback = Utils.overwrittenFunction(
		configScreen.buyButton.onClickCallback, onClick)
	configScreen.leaseButton.onClickCallback = Utils.overwrittenFunction(
		configScreen.leaseButton.onClickCallback, onClick)

	--- Adds the additional license plate menu.
	g_gui.guis.LicensePlateDialog.onOpen = Utils.prependedFunction(g_gui.guis.LicensePlateDialog.onOpen, onOpen)

	--- Base cp folder
	LicensePlateStorage.baseDir = g_modSettingsDirectory .. LicensePlateStorage.MOD_NAME .. "/"
	createFolder(LicensePlateStorage.baseDir)
	--- Base cp folder
	LicensePlateStorage.xmlFileName = LicensePlateStorage.baseDir.."LicensePlateManger.xml"

	LicensePlateStorage.xmlSchema = XMLSchema.new("LicensePlateStorage")
	LicensePlateStorage.xmlSchema:register(XMLValueType.BOOL, LicensePlateStorage.baseXmlKey .. "#areDuplicatesAllowed", "Duplicates allowed.", false)

	local xmlFile = XMLFile.loadIfExists("temp", LicensePlateStorage.xmlFileName, LicensePlateStorage.xmlSchema)
	if xmlFile then 
		LicensePlateStorage.areDuplicatesAllowed = xmlFile:getValue(LicensePlateStorage.baseXmlKey .. "#areDuplicatesAllowed", false)
		xmlFile:delete()
	end

end
ShopConfigScreen.onFinishedLoading = Utils.appendedFunction(ShopConfigScreen.onFinishedLoading, onLoadMapFinished)
