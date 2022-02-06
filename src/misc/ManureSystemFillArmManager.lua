----------------------------------------------------------------------------------------------------
-- ManureSystemFillArmManager
----------------------------------------------------------------------------------------------------
-- Purpose: Manager to handle fill arms.
--
-- Copyright (c) Wopster, 2019
----------------------------------------------------------------------------------------------------

---@class ManureSystemFillArmManager
ManureSystemFillArmManager = {}
ManureSystemFillArmManager.COLLISION_MASK = 8194

local ManureSystemFillArmManager_mt = Class(ManureSystemFillArmManager)

function ManureSystemFillArmManager:new(modDirectory, customMt)
    local self = setmetatable({}, customMt or ManureSystemFillArmManager_mt)

    self.modDirectory = modDirectory
    self.typeByName = {}
    self.numTypes = 0

    return self
end

function ManureSystemFillArmManager:loadMapData()
    local collisionFilename = Utils.getFilename("resources/collisions/fillArmCollision.i3d", self.modDirectory)
    local collisionRoot = g_i3DManager:loadSharedI3DFile(collisionFilename, false, false)

    self.collision = getChildAt(collisionRoot, 0)
    setCollisionMask(self.collision, ManureSystemFillArmManager.COLLISION_MASK)
end

function ManureSystemFillArmManager:unloadMapData()
    delete(self.collision)
end
