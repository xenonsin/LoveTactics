-- Player logic. Defaults live in data/player.lua; `Player.new` builds the
-- mutable runtime state, including instantiated party members.

local Character = require("models.character")

local Player = {}

Player.defaults = require("data.player")

-- Build fresh mutable player state for a new game.
function Player.new()
    local party = {}
    for _, charId in ipairs(Player.defaults.startingParty) do
        party[#party + 1] = Character.instantiate(charId)
    end

    return {
        gold = Player.defaults.gold,
        prestige = Player.defaults.prestige,
        party = party,
    }
end

return Player
