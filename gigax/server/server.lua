------------------------------------------------
-- Server --------------------------------------
------------------------------------------------
mod = {}

mod._init = function(self)
    -- Initialize tables to hold NPC and location data
    print("Initializing Gigax mod...")
    self._engineId = nil
    self._locationId = nil
    self._character = nil
    self._npcData = {}
    self._locationData = {}
end

mod.receiveEvent = function (self, e)
    if e.action == "registerNPC" then
        mod:_registerNPC(e.avatarId, e.physicalDescription, e.psychologicalProfile, e.currentLocationName)
    elseif e.action == "registerLocation" then
        mod:_registerLocation(e.name, e.position, e.description)
    elseif e.action == "registerEngine" then
        mod:_registerEngine(e.Sender, e.api_url, e.api_token)
    elseif e.action == "stepMainCharacter" then
        mod:_stepMainCharacter(self._character, self._engineId, e.actionType, self._npcData["aduermael"]._id, self._npcData["aduermael"].name, e.content, e.api_url, e.api_token)
    elseif e.action == "updateCharacterLocation" then
        local closest = self:_findClosestLocation(e.position, self._locationData)
        -- if closest._id is different from the current location, update the character's location
        if self._character == nil then
            print("Character not created yet; cannot update location.")
            return
        end
        if closest._id ~= self._character.current_location._id then
            mod:_updateCharacterLocation(self._engineId, e.characterId, closest._id, e.api_url, e.api_token)
        end
    else
        print("Unknown Gigax message received from mod.")
    end
end

-- Function to create and register an NPC
mod._registerNPC = function(self, avatarId, physicalDescription, psychologicalProfile, currentLocationName)
    -- Add NPC to npcData table
    self._npcData[avatarId] = {
        name = avatarId,
        physical_description = physicalDescription,
        psychological_profile = psychologicalProfile,
        current_location_name = currentLocationName,
        skills = {
            {
                name = "say",
                description = "Say smthg out loud",
                parameter_types = {"character", "content"}
            },
            -- {
            --     name = "move",
            --     description = "Move to a new location",
            --     parameter_types = {"location"}
            -- },
            {
                name = "greet",
                description = "Greet a character by waving your hand at them",
                parameter_types = {"character"}
            },
            -- {
            --     name = "follow",
            --     description = "Follow a character around for a while",
            --     parameter_types = {"character"}
            -- },
            {
                name = "jump",
                description = "Jump in the air",
            }
        }
    }
end

-- Function to register a location
mod._registerLocation = function(self, name, position, description)
    self._locationData[name] = {
        position = {x = position._x, y = position._y, z = position._z},
        name = name,
        description = description
    }
end

mod._registerEngine = function(self, sender, api_url, api_token)
    local apiUrl = api_url .. "/api/engine/company/"
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = api_token
    }

    -- Prepare the data structure expected by the backend
    local engineData = {
        name = "server_test",
        NPCs = {},
        locations = {} -- Populate if you have dynamic location data similar to NPCs
    }

    for _, npc in pairs(self._npcData) do
        table.insert(engineData.NPCs, {
            name = npc.name,
            physical_description = npc.physical_description,
            psychological_profile = npc.psychological_profile,
            current_location_name = npc.current_location_name,
            skills = npc.skills
        })
    end

    -- Populate locations
    for _, loc in pairs(self._locationData) do
        table.insert(engineData.locations, {
            name = loc.name,
            position = loc.position,
            description = loc.description
        })
    end

    local body = JSON:Encode(engineData)

    HTTP:Post(apiUrl, headers, body, function(res)
        if res.StatusCode ~= 201 then
            print("Error updating engine: " .. res.StatusCode)
            return
        end
        -- Decode the response body to extract engine and location IDs
        local responseData = JSON:Decode(res.Body)
        
        -- Save the engine_id for future use
        self._engineId = responseData.engine.id
        
        -- Saving all the _ids inside locationData table:
        for _, loc in pairs(responseData.locations) do
            self._locationData[loc.name]._id = loc._id
        end

        -- same for characters:
        for _, npc in pairs(responseData.NPCs) do
            self._npcData[npc.name]._id = npc._id
            local e = Event()
            e.action = "NPCRegistered"
            e.npcName = npc.name
            e.npcId = npc._id
            e["gigax.engineId"] = self._engineId
            e:SendTo(sender)
        end

        
        self:_registerMainCharacter(self._engineId, self._locationData["Medieval Inn"]._id, sender, api_url, api_token)
        -- print the location data as JSON
    end)
end

mod._registerMainCharacter = function(self, engineId, locationId, sender, api_url, api_token)
    -- Example character data, replace with actual data as needed
    local newCharacterData = {
        name = "oncheman",
        physical_description = "A human playing the game",
        current_location_id = locationId,
        position = {x = 0, y = 0, z = 0}
    }

    -- Serialize the character data to JSON
    local jsonData = JSON:Encode(newCharacterData)

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = api_token
    }

    local apiUrl = api_url .. "/api/character/company/main?engine_id=" .. engineId

    -- Make the HTTP POST request
    HTTP:Post(apiUrl, headers, jsonData, function(response)
        if response.StatusCode ~= 200 then
            print("Error creating or fetching main character: " .. response.StatusCode)
        end
        mod._character = JSON:Decode(response.Body)
        local e = Event()
        e.action = "mainCharacterCreated"
        e["character"] = self._character
        e:SendTo(sender)
    end)
end

mod._stepMainCharacter = function(self, character, engineId, actionType, targetId, targetName, content, api_url, api_token)
    -- Now, step the character
    local stepUrl = api_url .. "/api/character/" .. character._id .. "/step-no-ws?engine_id=" .. engineId 
    local stepActionData = {
        character_id = character._id,  -- Use the character ID from the creation/fetch response
        action_type = actionType,
        target = targetId,
        target_name = targetName,
        content = content
    }
    local stepJsonData = JSON:Encode(stepActionData)
    print("Stepping character with data: " .. stepJsonData)

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = api_token
    }
    -- You might need to adjust headers or use the same if they include the needed Authorization
    HTTP:Post(stepUrl, headers, stepJsonData, function(stepResponse)
        if stepResponse.StatusCode ~= 200 then
            -- print("Error stepping character: " .. stepResponse.StatusCode)
            return
        end
        
        local actions = JSON:Decode(stepResponse.Body)
        -- Find the target character by id using the "target" field in the response:
        for _, action in ipairs(actions) do
            local e = Event()
            e.action = "NPCActionResponse"
            e.actionType = action.action_type
            e.content = action.content
            for _, npc in pairs(self._npcData) do
                if action.character_id == npc._id then
                    -- Perform the action on the target character
                    e.protagonistId = npc._id
                elseif action.target == npc._id then
                    -- Perform the action on the target character
                    e.targetId = npc._id
                end
            end
            e:SendTo(Players)
        end
    end)
end

mod._updateCharacterLocation = function(self, engineId, characterId, locationId, api_url, api_token)
    local updateData = {
        -- Fill with necessary character update information
        current_location_id = locationId
    }
    
    local jsonData = JSON:Encode(updateData)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = api_token
    }
    
    -- Assuming `characterId` and `engineId` are available globally or passed appropriately
    local apiUrl = api_url .. "/api/character/" .. characterId .. "?engine_id=" .. engineId
    
    HTTP:Post(apiUrl, headers, jsonData, function(response)
        if response.StatusCode ~= 200 then
            print("Error updating character location: " .. response.StatusCode)
            return
        end
        self._character = JSON:Decode(response.Body)
    end)
end

-- Function to calculate distance between two positions
mod._calculateDistance = function(_, pos1, pos2)
    local dx = pos1.X - pos2.x
    local dy = pos1.Y - pos2.y
    local dz = pos1.Z - pos2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

mod._findClosestLocation = function (self, playerPosition, locationData)
    -- Assume `playerPosition` holds the current position of the player
    local closestLocation = nil
    local smallestDistance = math.huge -- Large initial value
    
    for _, location in pairs(locationData) do
        local distance = self:_calculateDistance(playerPosition, location.position)
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


return mod