-- DELVE: down, then up again, deeper. The Dwarf Delver's own trick, and it drops off the Delver as a
-- saboteur's piece -- a way under the line (reviewed 2026-09-24, "The Dwarves of Greed", both as the
-- mechanic and as the drop).
--
-- A WIND-UP, THE WYVERN'S SHAPE TURNED UPSIDE DOWN (data/items/ability/ability_take_wing.lua). On commit
-- the caster goes Underground (`channelStatus`): untargetable and unharmable for the turn it is under,
-- while the channel's ghost shows the tile it will come up on -- the telegraph a turn early. When the
-- channel resolves it surfaces there (or beside it, if somebody is standing on it), strikes every foe
-- adjacent to the exit for impact, and takes a stack of Deeper (+1 Damage, to three) for the rest of the
-- fight. Each dive makes the next one hurt more.
--
-- THE COUNTERPLAY IS THE TELEGRAPH: stand clear of the exit, or be waiting beside it with a hammer.
--
-- THE GOLEMS DELVE TOO (2026-09-25, "The Golems of Greed": they carry this very item rather than a copy
-- of it). What is theirs alone is the VEIN: a bearer of `strikesVein` (trait_strikes_vein) leaves the
-- hole it sank through as a coin heap, or one time in three a lava pit (models/golem.lua) -- and never
-- brings the cave-in, which stays the Delver's own.
local Curve = require("models.curve")
local Status = require("models.status")

return {
    name = "Delve",
    description = "Surfaces a turn later on a tile up to 5 away, striking adjacent foes. Each Delve adds 1 Damage, to 3.",
    flavor = "Every dwarf knows the floor is only the roof of something else.",
    sprite = "assets/items/ability_delve.png",
    type = "ability",
    tags = { "earth", "impact", "physical" },
    class = "saboteur",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 5,
        speed = 4,
        windup = 5, -- a turn under the floor
        cooldown = 15, -- three turns: a delve is a commitment, not a stride
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(9, 19), -- the floor coming up under whoever stands beside the exit (slot 5's
                                    -- target, tests/balance_spec.lua)
        channelStatus = "status_underground",
        usable = function(unit)
            if Status.blocksMove(unit) then return false, "Cannot move" end
            return true
        end,
        effect = function(fx)
            if fx.clearStatus then fx.clearStatus(fx.user, "status_underground") end
            local x, y = fx.tx, fx.ty
            local fromX, fromY = fx.user.x, fx.user.y -- the hole it sank through
            local occupant = fx.unitAt(x, y)
            if occupant and occupant ~= fx.user then x, y = fx.openTileNear(x, y) end
            if x and y then fx.teleportUser(x, y) end
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u ~= fx.user and u.alive and u.side ~= fx.user.side then fx.damage(u) end
            end
            fx.applyStatus(fx.user, "status_deeper", { magnitude = 1 })
            -- DELVED TOO GREEDILY AND TOO DEEP (round 3): the dive that brings Deeper to three brings the
            -- roof down. A status, so the lava is laid only live (status_cave_in explains why).
            local Trait = require("models.trait")
            -- UP FROM BELOW: a bearer of the Deep-Delver's Pick comes up ready (status_surfaced), and its
            -- next landed blow is a critical. Stamped only there, so a dwarf line wears no empty badge.
            if Trait.flag(fx.user, "critOnSurfacing") then fx.applyStatus(fx.user, "status_surfaced") end
            if Trait.flag(fx.user, "strikesVein") then
                -- Only live: a preview's board is the real one, and a vein is struck once.
                if fx.combat and fx.combat.arena and (fromX ~= fx.user.x or fromY ~= fx.user.y) then
                    require("models.golem").strikeVein(fx.combat, fx.user, fromX, fromY)
                end
            elseif require("models.status").stacksOf(fx.user, "status_deeper") >= 3 then
                fx.applyStatus(fx.user, "status_cave_in")
            end
        end,
    },
}
