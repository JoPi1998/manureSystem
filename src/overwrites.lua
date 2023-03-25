--
-- overwrites
--
-- Author: Stijn Wopereis
-- Description: Handle overwrites
-- Name: overwrites
-- Hide: yes
--
-- Copyright (c) Wopster, 2023

---@class pnh_overwrite
manureSystem_overwrite = {}

---@type table
local originalFunctions = {}

----------------
-- Overwrites --
----------------

local function objectHasConnectors(object)
    return object ~= nil and object.hasConnectors ~= nil and object:hasConnectors()
end

local function inj_fillTrigger_getIsActivatable(trigger, superFunc, vehicle, ...)
    if vehicle.getConnectorById ~= nil then
        if objectHasConnectors(trigger.sourceObject) or objectHasConnectors(trigger.sourceObject.owner) then
            return false
        end
    end

    return superFunc(trigger, vehicle, ...)
end

local function inj_loadTrigger_getAllowsActivation(trigger, superFunc, object, ...)
    if object.getConnectorById ~= nil then
        return false
    end

    return superFunc(trigger, object, ...)
end

local function inj_loadTrigger_getIsFillableObjectAvailable(trigger, superFunc, ...)
    if objectHasConnectors(trigger.source) or objectHasConnectors(trigger.source.owner) then
        for _, filleable in pairs(trigger.fillableObjects) do
            if filleable.object.getConnectorById ~= nil then
                return false
            end
        end
    end

    return superFunc(trigger, ...)
end


function SleepManager:getCanSleep()
    return false
end

---Early hook to overwrite
function manureSystem_overwrite.init()
    manureSystem_overwrite.overwrittenFunction(FillTrigger, "getIsActivatable", inj_fillTrigger_getIsActivatable)
    manureSystem_overwrite.overwrittenFunction(LoadTrigger, "getAllowsActivation", inj_loadTrigger_getAllowsActivation)
    manureSystem_overwrite.overwrittenFunction(LoadTrigger, "getIsFillableObjectAvailable", inj_loadTrigger_getIsFillableObjectAvailable)
end

---Store the original function on consoles
local function storeOriginalFunction(target, name)
    if not GS_IS_CONSOLE_VERSION then
        return
    end

    if originalFunctions[target] == nil then
        originalFunctions[target] = {}
    end

    -- Store the original function
    if originalFunctions[target][name] == nil then
        originalFunctions[target][name] = target[name]
    end
end

---Overwrite the vanilla function and store
function manureSystem_overwrite.overwrittenFunction(target, name, newFunc)
    storeOriginalFunction(target, name)
    target[name] = Utils.overwrittenFunction(target[name], newFunc)
end

---Append the vanilla function and store
function manureSystem_overwrite.appendedFunction(target, name, newFunc)
    storeOriginalFunction(target, name)
    target[name] = Utils.appendedFunction(target[name], newFunc)
end

---Prepend the vanilla function and store
function manureSystem_overwrite.prependedFunction(target, name, newFunc)
    storeOriginalFunction(target, name)
    target[name] = Utils.prependedFunction(target[name], newFunc)
end

---Reset the vanilla functions to it's original state
function manureSystem_overwrite.resetOriginalFunctions()
    for target, functions in pairs(originalFunctions) do
        for name, func in pairs(functions) do
            target[name] = func
        end
    end
end