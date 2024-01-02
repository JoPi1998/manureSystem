--
-- ManureSystemFillArmReceiver
--
-- Author: Stijn Wopereis
-- Description: Allows fillArm interaction with vehicles
-- Name: ManureSystemFillArmReceiver
-- Hide: yes
--
-- Copyright (c) Wopster, 2023

---@class ManureSystemFillArmReceiver
ManureSystemFillArmReceiver = {}
ManureSystemFillArmReceiver.MOD_NAME = g_currentModName

---@return void
function ManureSystemFillArmReceiver.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("ManureSystemFillArmReceiver")
    ManureSystem.registerConfigurationRestrictionsXMLPaths(schema, "vehicle.manureSystemFillArmReceiver")
    schema:register(XMLValueType.INT, "vehicle.manureSystemFillArmReceiver#fillVolumeIndex", "Fill volume index to interact with")
    schema:register(XMLValueType.INT, "vehicle.manureSystemFillArmReceiver#fillUnitIndex", "Fill unit index to pump from")
    schema:register(XMLValueType.FLOAT, "vehicle.manureSystemFillArmReceiver#fillArmOffset", "Offset for the fillarm interaction")
    schema:setXMLSpecializationType()
end

---@return boolean
function ManureSystemFillArmReceiver.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(FillVolume, specializations)
end

---@return void
function ManureSystemFillArmReceiver.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getSupportsFillArms", ManureSystemFillArmReceiver.getSupportsFillArms)
    SpecializationUtil.registerFunction(vehicleType, "getFillArmFillUnitIndex", ManureSystemFillArmReceiver.getFillArmFillUnitIndex)
    SpecializationUtil.registerFunction(vehicleType, "isUnderFillPlane", ManureSystemFillArmReceiver.isUnderFillPlane)
end

---@return void
function ManureSystemFillArmReceiver.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ManureSystemFillArmReceiver)
end

---@return void
function ManureSystemFillArmReceiver:onLoad(savegame)
    self.spec_manureSystemFillArmReceiver = self[("spec_%s.manureSystemFillArmReceiver"):format(ManureSystemFillArmReceiver.MOD_NAME)]
    local spec = self.spec_manureSystemFillArmReceiver

    spec.isActive = self.xmlFile:getBool("vehicle.manureSystem#hasFillArmReceiver") or false

    if not spec.isActive then
        return
    end

    if #self.spec_fillVolume.volumes == 0 then
        spec.isActive = false
        return
    end

    if not g_currentMission.manureSystem:getAreConfigurationRestrictionsFulfilled(self, self.xmlFile, "vehicle.manureSystemFillArmReceiver") then
        spec.isActive = false
        return
    end

    local fillVolumeIndex = self.xmlFile:getValue("vehicle.manureSystemFillArmReceiver#fillVolumeIndex", 1)
    if self.spec_fillVolume.volumes[fillVolumeIndex] == nil then
        Logging.xmlWarning(self.configFileName, "Invalid fillVolumeIndex '%d'!", fillVolumeIndex)
        spec.isActive = false
        return
    end

    spec.fillVolumeIndex = fillVolumeIndex

    spec.fillArmOffset = self.xmlFile:getValue("vehicle.manureSystemFillArmReceiver#fillArmOffset", 0)
    spec.fillArmFillUnitIndex = self.xmlFile:getValue("vehicle.manureSystemFillArmReceiver#fillUnitIndex", 1)
end

---@return boolean
function ManureSystemFillArmReceiver:getSupportsFillArms()
    local spec = self.spec_manureSystemFillArmReceiver

    if not spec.isActive then
        return false
    end

    local volumes = self.spec_fillVolume.volumes
    if #volumes == 0 or volumes[spec.fillVolumeIndex] == nil or volumes[spec.fillVolumeIndex].volume == nil then
        return false
    end

    return true
end

---@return number
function ManureSystemFillArmReceiver:getFillArmFillUnitIndex()
    return self.spec_manureSystemFillArmReceiver.fillArmFillUnitIndex
end

---@return boolean
function ManureSystemFillArmReceiver:isUnderFillPlane(x, y, z)
    local spec = self.spec_manureSystemFillArmReceiver
    if not spec.isActive then
        return false
    end

    local fillVolumeIndex = spec.fillVolumeIndex
    local volume = self.spec_fillVolume.volumes[fillVolumeIndex].volume
    if volume == nil or not getVisibility(volume) then
        return false
    end

    local xl, _, zl = worldToLocal(volume, x, y, z)
    local height = getFillPlaneHeightAtLocalPos(volume, xl, zl)
    local _, volumeWorldY, _ = localToWorld(volume, xl, height, zl)

    volumeWorldY = volumeWorldY + spec.fillArmOffset

    return volumeWorldY >= y
end
