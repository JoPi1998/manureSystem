----------------------------------------------------------------------------------------------------
-- ManureSystem
----------------------------------------------------------------------------------------------------
-- Purpose: Main class the handle the Manure System.
--
-- Copyright (c) Wopster, 2019
----------------------------------------------------------------------------------------------------

---@class ManureSystem
---@field connectorManager ManureSystemConnectorManager
---@field fillArmManager ManureSystemFillArmManager
---@field player HosePlayer
ManureSystem = {}

local ManureSystem_mt = Class(ManureSystem)

---Sorter to manage saving and loading hoses from savegame.
local sortByClassAndId = function(arg1, arg2)
    -- Sort by id when dealing with the same classNames.
    if arg1.className == arg2.className then
        local id1 = g_currentMission.manureSystem.savedVehiclesToId[arg1] or g_currentMission.manureSystem.savedItemsToId[arg1] or 0
        local id2 = g_currentMission.manureSystem.savedVehiclesToId[arg2] or g_currentMission.manureSystem.savedItemsToId[arg2] or 0

        return id1 < id2
    end

    return arg1.className < arg2.className
end

function ManureSystem.new(mission, input, soundManager, modDirectory, modName)
    local self = setmetatable({}, ManureSystem_mt)

    self.version = 2
    self.isServer = mission:getIsServer()
    self.isClient = mission:getIsClient()
    self.modDirectory = modDirectory
    self.modName = modName

    --Debug flags
    self.debug = true
    self.debugShowConnectors = false

    self.mission = mission
    self.soundManager = soundManager
    self.connectorManager = ManureSystemConnectorManager.new(self.modDirectory)
    self.fillArmManager = ManureSystemFillArmManager.new(self.modDirectory)
    self.player = HosePlayer.new(self.isClient, self.isServer, mission, input)
    --self.husbandryModuleLiquidManure = ManureSystemHusbandryModuleLiquidManure:new(self.isClient, self.isServer, mission, input)
    --self.bga = ManureSystemBga:new(self.isClient, self.isServer, mission, input)

    self.manureSystemConnectors = {}
    self.samples = {}

    self:loadManureSystemSamples()

    self.textureArrayIndexToFillTypeIndex = {}
    for _, fillType in ipairs(g_fillTypeManager:getFillTypes()) do
        if fillType.textureArrayIndex ~= nil then
            self.textureArrayIndexToFillTypeIndex[fillType.textureArrayIndex] = fillType.index
        end
    end

    addConsoleCommand("msToggleDebug", "Toggle debugging", "consoleCommandToggleDebug", self)
    addConsoleCommand("msToggleConnectorNodes", "Toggle connector node", "consoleCommandToggleConnectors", self)

    return self
end

function ManureSystem:delete()
    self.player:delete()
    --self.husbandryModuleLiquidManure:delete()
    --self.bga:delete()

    self.connectorManager:unloadMapData()
    self.fillArmManager:unloadMapData()

    self.soundManager:deleteSamples(self.samples)
    removeConsoleCommand("msToggleDebug")
    removeConsoleCommand("msToggleConnectorNodes")
end

function ManureSystem:onMissionLoaded(mission)
    self.connectorManager:loadMapData()
    self.fillArmManager:loadMapData()
end

---Gets the mission item save list.
function ManureSystem:getSavedItemsList()
    local savedItemsToId = {}

    local id = 1
    for _, placeable in ipairs(self.mission.placeableSystem.placeables) do
        if placeable:getNeedsSaving() then
            savedItemsToId[placeable] = id
            id = id + 1
        end
    end

    return savedItemsToId
end

---Gets the mission vehicle save list.
function ManureSystem:getSavedVehiclesList()
    local savedVehiclesToId = {}

    local id = 1
    for _, vehicle in ipairs(self.mission.vehicles) do
        if vehicle.isVehicleSaved then
            savedVehiclesToId[vehicle] = id
            id = id + 1
        end
    end

    return savedVehiclesToId
end

---Called when mission is loaded.
function ManureSystem:load(xmlFilename)
    local xmlFile = XMLFile.load("ManureSystemXML", xmlFilename)
    if xmlFile ~= nil then
        self:loadFromXML(xmlFile)
        xmlFile:delete()
    end
end
---Called when mission is loaded.
function ManureSystem:loadFromXML(xmlFile)
    local version = xmlFile:getInt("manureSystem#version")
    local validVersion = not (version ~= nil and version < self.version)

    if not validVersion then
        Logging.warning("Skipping loading of saved hose connections due to loading from an older ManureSystem savegame!")
    end

    self.savedVehiclesToId = self:getSavedVehiclesList()
    self.savedItemsToId = self:getSavedItemsList()
    table.sort(self.manureSystemConnectors, sortByClassAndId)

    local i = 0
    while true do
        local key = ("manureSystem.hoses.hose(%d)"):format(i)
        if not xmlFile:hasProperty(key) then
            break
        end

        local hoseId = xmlFile:getInt(key .. "#objectId")
        if self:connectorObjectExists(hoseId) then
            local object = self:getConnectorObject(hoseId)
            if object.isaHose ~= nil and object:isaHose() then
                object:loadFromXML(key, xmlFile, validVersion)
            end
        end

        i = i + 1
    end
end

function ManureSystem:save(xmlFilename)
    local xmlFile = XMLFile.create("ManureSystemXML", xmlFilename, "manureSystem")
    if xmlFile ~= nil then
        self:saveToXML(xmlFile)
        xmlFile:delete()
    end
end

---Called when mission is being saved with our own xml file.
function ManureSystem:saveToXML(xmlFile)
    xmlFile:setInt("manureSystem#version", self.version)

    self.savedVehiclesToId = self:getSavedVehiclesList()
    self.savedItemsToId = self:getSavedItemsList()
    table.sort(self.manureSystemConnectors, sortByClassAndId)

    local hoses = {}
    local objectToId = {}
    for id, object in ipairs(self.manureSystemConnectors) do
        if object.isaHose ~= nil and object:isaHose() then
            objectToId[object] = id
            table.insert(hoses, object)
        end
    end

    -- We only need to store the hoses information.
    for i, object in ipairs(hoses) do
        local id = objectToId[object]
        local key = ("manureSystem.hoses.hose(%d)"):format(i - 1)
        xmlFile:setInt(key .. "#objectId", id)
        object:saveToXML(key, xmlFile)
    end

    xmlFile:save()
end

---Loads the shared sample files for the manure system.
function ManureSystem:loadManureSystemSamples()
    local xmlFile = XMLFile.load("ManureSystemSamples", Utils.getFilename("resources/sounds.xml", self.modDirectory))
    if xmlFile ~= nil then
        local soundsNode = getRootNode()
        self.samples.pump = self.soundManager:loadSampleFromXML(xmlFile.handle, "vehicle.sounds", "pump", self.modDirectory, soundsNode, 1, AudioGroup.VEHICLE, nil, nil)
        xmlFile:delete()
    end
end

---Returns the current loaded samples.
function ManureSystem:getManureSystemSamples()
    return self.samples
end

---Returns the fill type index for the given texture array index.
function ManureSystem:getFillTypeIndexByTextureArrayIndex(textureArrayIndex)
    return self.textureArrayIndexToFillTypeIndex[textureArrayIndex]
end

---Adds connector object to the list and force it being distinct.
function ManureSystem:addConnectorObject(object)
    if not table.hasElement(self.manureSystemConnectors, object) then
        table.addElement(self.manureSystemConnectors, object)
    end
end

---Removes connector object from the list.
function ManureSystem:removeConnectorObject(object)
    table.removeElement(self.manureSystemConnectors, object)
end

---Returns the connector objects list.
function ManureSystem:getConnectorObjects()
    return self.manureSystemConnectors
end

---Returns the connector with the given id.
function ManureSystem:getConnectorObject(id)
    return self.manureSystemConnectors[id]
end

---Return the id for the given object.
function ManureSystem:getConnectorObjectId(object)
    return table.findListElementFirstIndex(self.manureSystemConnectors, object)
end

---Return true when the object exists, false otherwise.
function ManureSystem:connectorObjectExists(id)
    return self.manureSystemConnectors[id] ~= nil
end

function ManureSystem.hasManureSystemRegistry(typeName, specializationManager)
    local stringParts = string.split(typeName, ".")
    if #stringParts ~= 1 then
        local typeModName = unpack(stringParts)
        return specializationManager:getSpecializationObjectByName(typeModName .. ".manureSystemRegistry") ~= nil
    end

    return false
end

function ManureSystem.insertPumpMotor(vehicleTypeManager, typeName, typeEntry, modName)
    if not SpecializationUtil.hasSpecialization(ManureSystemPumpMotor, typeEntry.specializations) then
        vehicleTypeManager:addSpecialization(typeName, modName .. ".manureSystemPumpMotor")
        Logging.info(("Adding ManureSystemPumpMotor to: '%s'"):format(typeName))
    end
end

function ManureSystem.insertConnector(vehicleTypeManager, typeName, typeEntry, modName)
    if not SpecializationUtil.hasSpecialization(ManureSystemConnector, typeEntry.specializations)
        and SpecializationUtil.hasSpecialization(FillUnit, typeEntry.specializations) then
        vehicleTypeManager:addSpecialization(typeName, modName .. ".manureSystemConnector")
        Logging.info(("Adding ManureSystemConnector to: '%s'"):format(typeName))
    end
end

function ManureSystem.insertFillArm(vehicleTypeManager, typeName, typeEntry, modName)
    if not SpecializationUtil.hasSpecialization(ManureSystemFillArm, typeEntry.specializations)
        and SpecializationUtil.hasSpecialization(FillUnit, typeEntry.specializations) then
        vehicleTypeManager:addSpecialization(typeName, modName .. ".manureSystemFillArm")
        Logging.info(("Adding ManureSystemFillArm to: '%s'"):format(typeName))
    end
end

function ManureSystem.insertFillArmReceiver(vehicleTypeManager, typeName, typeEntry, modName)
    if not SpecializationUtil.hasSpecialization(ManureSystemFillArmReceiver, typeEntry.specializations)
        and SpecializationUtil.hasSpecialization(FillUnit, typeEntry.specializations)
        and SpecializationUtil.hasSpecialization(FillVolume, typeEntry.specializations) then
        vehicleTypeManager:addSpecialization(typeName, modName .. ".manureSystemFillArmReceiver")
        Logging.info(("Adding ManureSystemFillArmReceiver to: '%s'"):format(typeName))
    end
end

function ManureSystem.insertMixer(vehicleTypeManager, typeName, typeEntry, modName)
    if not SpecializationUtil.hasSpecialization(ManureSystemMixer, typeEntry.specializations)
        and SpecializationUtil.hasSpecialization(TurnOnVehicle, typeEntry.specializations) then
        vehicleTypeManager:addSpecialization(typeName, modName .. ".manureSystemMixer")
        Logging.info(("Adding ManureSystemMixer to: '%s'"):format(typeName))
    end
end

function ManureSystem.installVehicleSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
    for typeName, typeEntry in pairs(vehicleTypeManager:getTypes()) do
        local hasRegistry = ManureSystem.hasManureSystemRegistry(typeName, specializationManager)
        local isValidTypeManureVehicle = typeName == "manureTrailer" or SpecializationUtil.hasSpecialization(ManureBarrel, typeEntry.specializations)
        local isValidTypeSprayer = typeName == "sprayer" or typeName == "selfPropelledSprayer"

        if hasRegistry then
            ManureSystem.insertMixer(vehicleTypeManager, typeName, typeEntry, modName)
        end

        if typeName == "pallet" and SpecializationUtil.hasSpecialization(FillUnit, typeEntry.specializations) then
            ManureSystem.insertConnector(vehicleTypeManager, typeName, typeEntry, modName)
        end

        if isValidTypeManureVehicle or isValidTypeSprayer or hasRegistry then
            ManureSystem.insertPumpMotor(vehicleTypeManager, typeName, typeEntry, modName)
            ManureSystem.insertConnector(vehicleTypeManager, typeName, typeEntry, modName)
            ManureSystem.insertFillArm(vehicleTypeManager, typeName, typeEntry, modName)
            ManureSystem.insertFillArmReceiver(vehicleTypeManager, typeName, typeEntry, modName)
        end
    end
end

function ManureSystem.insertPlaceableSpec(typeManager, typeName, typeEntry, specializationManager, specName, modName)
    local specializationObject = specializationManager:getSpecializationObjectByName(modName .. "." .. specName)
    if specializationObject ~= nil then
        if not SpecializationUtil.hasSpecialization(specializationObject, typeEntry.specializations) and specializationObject.prerequisitesPresent(typeEntry.specializations) then
            typeManager:addSpecialization(typeName, modName .. "." .. specName)
            Logging.info("Adding '%s' to: '%s'", specName, typeName)

            return true
        end
    end

    return false
end

function ManureSystem.installPlaceableSpecializations(typeManager, specializationManager, modDirectory, modName)
    local specNames = {
        "manureSystemPlaceableSilo",
        "manureSystemPlaceableSiloExtension",
        "manureSystemPlaceableHusbandry",
        "manureSystemPlaceableProductionPoint",
        "manureSystemPlaceableSellingStation",
        "manureSystemPlaceableBuyingStation"
    }

    for typeName, typeEntry in pairs(typeManager:getTypes()) do
        local success = ManureSystem.hasManureSystemRegistry(typeName, specializationManager)

        for _, specName in ipairs(specNames) do
            if ManureSystem.insertPlaceableSpec(typeManager, typeName, typeEntry, specializationManager, specName, modName) then
                success = true
            end
        end

        if success then
            ManureSystem.insertPlaceableSpec(typeManager, typeName, typeEntry, specializationManager, "manureSystemPlaceableBase", modName)
            ManureSystem.insertPlaceableSpec(typeManager, typeName, typeEntry, specializationManager, "manureSystemPlaceableConnector", modName)
            ManureSystem.insertPlaceableSpec(typeManager, typeName, typeEntry, specializationManager, "manureSystemPlaceableFillArmReceiver", modName)
        end
    end
end

---Add our global translations to the global table.
function ManureSystem.addModTranslations(i18n)
    local global = getfenv(0).g_i18n.texts
    for key, text in pairs(i18n.texts) do
        if string.startsWith(key, "global_") then
            global[key:sub(8)] = text
        end
    end
end

---Remove are global entries to avoid duplications.
function ManureSystem.removeModTranslations(i18n)
    local global = getfenv(0).g_i18n.texts
    for key, _ in pairs(i18n.texts) do
        if string.startsWith(key, "global_") then
            global[key:sub(8)] = nil
        end
    end
end

----------------------
-- Commands
----------------------

---Raise all manure system connector objects active.
function ManureSystem:wakeupManureSystemConnectors()
    for _, object in ipairs(self.manureSystemConnectors) do
        object:raiseActive()
    end
end

---Console command for showing general debug information.
function ManureSystem:consoleCommandToggleDebug()
    self.debug = not self.debug

    if self.debug then
        self:wakeupManureSystemConnectors()
    end

    return tostring(self.debug)
end

---Console command for highlighting the connector nodes.
function ManureSystem:consoleCommandToggleConnectors()
    self.debugShowConnectors = not self.debugShowConnectors

    if self.debugShowConnectors then
        self:wakeupManureSystemConnectors()
    end

    return tostring(self.debugShowConnectors)
end
