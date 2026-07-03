-- Player logic. Defaults live in data/player.lua; `Player.new` builds the
-- mutable runtime state: the full roster of owned characters plus the active
-- party (a capped subset of the roster).

local Character = require("models.character")

local Player = {}

Player.defaults = require("data.player")

-- Hard cap on the active party. The roster (owned characters) is unbounded;
-- only this many can be deployed at once.
Player.MAX_PARTY = 3

-- Base overworld fog-of-war vision radius (tiles seen around the player). A party
-- member carrying an item with a larger visionRadius (e.g. a torch) raises it.
Player.BASE_VISION = 2

-- Effective overworld vision radius for a player's active party: BASE_VISION raised
-- by the largest visionRadius of any item any party member is carrying. Kept here so
-- the "does the party have a torch" logic lives in one place; the item's field is the
-- single source of truth. A nil player (dev/test) returns the base.
function Player.visionRadius(player)
    local r = Player.BASE_VISION
    if player and player.party then
        for _, char in ipairs(player.party) do
            for _, item in ipairs(char.inventory or {}) do
                if item.visionRadius and item.visionRadius > r then r = item.visionRadius end
            end
        end
    end
    return r
end

-- Add a roster member to the active party, enforcing the party cap.
-- Returns true on success, false if the party is already full.
function Player.addToParty(player, char)
    if #player.party >= Player.MAX_PARTY then
        return false
    end
    player.party[#player.party + 1] = char
    return true
end

-- Remove a character from the active party (leaves them in the roster).
-- Returns true if the character was in the party.
function Player.removeFromParty(player, char)
    for i, member in ipairs(player.party) do
        if member == char then
            table.remove(player.party, i)
            return true
        end
    end
    return false
end

-- Build fresh mutable player state for a new game. Party members reference the
-- same instances held in the roster, so a character is instantiated once.
function Player.new()
    local roster = {}
    local byId = {}
    for _, charId in ipairs(Player.defaults.startingRoster) do
        local char = Character.instantiate(charId)
        roster[#roster + 1] = char
        byId[charId] = char
    end

    local player = {
        gold = Player.defaults.gold,
        prestige = Player.defaults.prestige,
        roster = roster,
        party = {},
    }

    for _, charId in ipairs(Player.defaults.startingParty) do
        local char = byId[charId]
        assert(char, "startingParty id not in roster: " .. tostring(charId))
        assert(Player.addToParty(player, char), "startingParty exceeds MAX_PARTY of " .. Player.MAX_PARTY)
    end

    return player
end

return Player
