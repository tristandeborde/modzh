--client--------------
----------------------

mod = {}

mod.init = function(self)
    self.npcDataClient = {}
end

mod.receiveClientEvent = function(self, e)
    if e.action == "NPCActionResponse" then
        mod:parseAction(e)
    elseif e.action == "mainCharacterCreated" then
        -- Setup a new timer to delay the next update call
        characterId = e.character._id
        updateLocationTimer = Timer(0.5, true, function()
            local e = Event()
            e.action = "updateCharacterLocation"
            e.position = Player.Position
            e.characterId = characterId
            e:SendTo(Server)
        end)
        -- print("Character ID: " .. character._id)
    elseif e.action == "NPCRegistered" then
        -- Update NPC in the client side table to add the _id
        for _, npc in pairs(self.npcDataClient) do
            if npc.name == e.npcName then
                npc._id = e.npcId
            end
        end
    end
end

mod.createNPC = function(_, avatarId, physicalDescription, psychologicalProfile, currentLocationName, currentPosition)
    -- Create the NPC's Object and Avatar
    local NPC = {}
    NPC.object = Object()
    World:AddChild(NPC.object)
    NPC.object.Position = currentPosition or Number3(0, 0, 0)
    NPC.object.Scale = 0.5
    NPC.object.Physics = PhysicsMode.Trigger
    NPC.object.CollisionBox = Box({
		-TRIGGER_AREA_SIZE.Width * 0.5,
		math.min(-TRIGGER_AREA_SIZE.Height, NPC.object.CollisionBox.Min.Y),
		-TRIGGER_AREA_SIZE.Depth * 0.5,
	}, {
		TRIGGER_AREA_SIZE.Width * 0.5,
		math.max(TRIGGER_AREA_SIZE.Height, NPC.object.CollisionBox.Max.Y),
		TRIGGER_AREA_SIZE.Depth * 0.5,
	})
    NPC.object.OnCollisionBegin = function(self, other)
        if other ~= Player then
            return
        end
        _helpers.lookAt(self.avatarContainer, other)
    end
    NPC.object.OnCollisionEnd = function(self, other)
        if other ~= Player then
            return
        end
        _helpers.lookAt(self.avatarContainer, nil)
    end

    local container = Object()
	container.Rotation = NPC.object.Rotation
	container.initialRotation = NPC.object.Rotation:Copy()
	container.initialForward = NPC.object.Forward:Copy()
	container:SetParent(NPC.object)
    container.Physics = PhysicsMode.Dynamic
	NPC.object.avatarContainer = container
    
    local avatar = require("avatar")
    NPC.avatar = avatar:get(avatarId)
    NPC.avatar:SetParent(NPC.object.avatarContainer)

    -- Register it
    local e = Event()
    e.action = "registerNPC"
    e.avatarId = avatarId
    e.physicalDescription = physicalDescription
    e.psychologicalProfile = psychologicalProfile
    e.currentLocationName = currentLocationName
    e:SendTo(Server)
    return NPC
end

mod.createLocation = function(_, name, position, description)
    local e = Event()
    e.action = "registerLocation"
    e.name = name
    e.position = position
    e.description = description
    e:SendTo(Server)
end

mod.findNPCById = function(self, id)
    for _, npc in pairs(self.npcDataClient) do
        -- print("Checking NPC with ID " .. npc._id)
        print("Looking for NPC with ID " .. id)
        if npc._id == id then
            return npc
        end
    end
end

mod.parseAction = function(self, action)
    local npc = self:findNPCById(action.protagonistId)
    if action.actionType == "GREET" then
        -- TODO: face action.target and wave hand
        dialog:create("<Greets you warmly!>", npc.avatar)
        npc.avatar.Animations.SwingRight:Play()
    elseif action.actionType == "SAY" then
        dialog:create(action.content, npc.avatar)
    elseif action.actionType == "JUMP" then
        dialog:create("<Jumps in the air!>", npc.avatar)
        npc.object.avatarContainer.Velocity.Y = 50
        timer = Timer(1, false, function()
            npc.object.avatarContainer.Velocity.Y = 50
        end)
    elseif action.actionType == "MOVE" then
        -- TODO
    elseif action.actionType == "FOLLOW" then
        -- TODO
    end
end

-- Function to calculate distance between two positions
mod.calculateDistance = function(_, pos1, pos2)
    local dx = pos1.X - pos2.x
    local dy = pos1.Y - pos2.y
    local dz = pos1.Z - pos2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

mod.findClosestLocation = function (self, playerPosition, locationData)
    -- Assume `playerPosition` holds the current position of the player
    local closestLocation = nil
    local smallestDistance = math.huge -- Large initial value
    
    for _, location in pairs(locationData) do
        local distance = self:calculateDistance(playerPosition, location.position)
        if distance < smallestDistance then
            smallestDistance = distance
            closestLocation = location
        end
    end
    
    if closestLocation then
        -- Closest location found, now send its ID to update the character's location
        return closestLocation
    end
end

mod.mod = mod
