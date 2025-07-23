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

--- Checks if the plate str is already given to another vehicle.
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
			cell:getAttribute("licensePlate"):setTextColor(1, 1, 1, 0.5)
			for ix, p in ipairs(self.sortedPlates) do 
				if ix ~= index and p == plate then 
					cell:getAttribute("licensePlate"):setTextColor(0.5, 0.5, 0, 1)
					break
				end
			end
		end
		
		self.target.onListSelectionChanged = function(self, list, section, index)
			
		end

		self.target.onClickItem = function(self, list, section, index, listElement)
			local v = self.sortedVehicles[index]
			if v ~= "" and v.spec_licensePlates ~= nil then
				LicensePlateStorage.debug("OnClick: %s / %s", 
					v:getName(), self.sortedPlates[index])
				self:setLicensePlateData(v.spec_licensePlates.licensePlateData)
				self:updateLicensePlateGraphics()

				self:onClickOk()
			end
		end

		self.target.getNumberOfSections = function(self)
			return 1
		end
		
		-- self.target.getTitleForSectionHeader = function(self)
		-- 	return ""
		-- end
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
		FocusManager:loadElementFromCustomValues(self.target.licensePlateList)
	end
	self.target.licensePlateList:reloadData()
end

local function onLoadMapFinished(configScreen, ...)
	-- --- Only allow buying, if the license plate is not given to another vehicle.
	-- local function onClick(self, superFunc, ...)
	-- 	if not g_licensePlateManager:getAreLicensePlatesAvailable()  then 
	-- 		return superFunc(self, ...)
	-- 	end
	-- 	LicensePlateStorage.debug("onClick")
	-- 	if self.licensePlateData then 
	-- 		local valid = LicensePlateStorage.validatePlates(self.licensePlateData, self.vehicle, self.storeItem)
	-- 		if not valid then 
	-- 			return
	-- 		end
	-- 	end
	-- 	return superFunc(self, ...)
	-- end
	-- configScreen.buyButton.onClickCallback = Utils.overwrittenFunction(
	-- 	configScreen.buyButton.onClickCallback, onClick)
	-- configScreen.leaseButton.onClickCallback = Utils.overwrittenFunction(
	-- 	configScreen.leaseButton.onClickCallback, onClick)

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

	LicensePlateDialog.updateFocusLinking = Utils.appendedFunction(
		LicensePlateDialog.updateFocusLinking, function (dialog)		
			FocusManager:linkElements(dialog.licensePlateList, 
				FocusManager.LEFT, dialog.buttonCursorRight)
			FocusManager:linkElements(dialog.changeColorButton, 
				FocusManager.RIGHT,dialog.buttonCursorLeft)
			FocusManager:linkElements(dialog.licensePlateList, 
				FocusManager.RIGHT, dialog.buttonCursorRight)
			FocusManager:linkElements(dialog.changeColorButton, 
				FocusManager.LEFT,dialog.buttonCursorLeft)
		end)

end
ShopConfigScreen.onFinishedLoading = Utils.appendedFunction(ShopConfigScreen.onFinishedLoading, onLoadMapFinished)
