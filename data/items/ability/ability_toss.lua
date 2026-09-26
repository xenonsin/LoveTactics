-- TOSS: the Goblin Cutter's throw, and the drop off it. Reviewed 2026-09-26 ("The Goblins of Wrath"): the
-- round-1 Throwing Cleaver was approved with Keno's note -- "better as an ability that you can toss any
-- adjacent weapon. needs to return when fight is over and you haven't picked it up" -- and round 2 approved
-- this reading of it as written.
--
-- IT THROWS THE WEAPON BESIDE IT (`requiresAdjacent`, the same "beside" Clear Out reads): at a foe within 4,
-- for that weapon's own damage. The weapon lands on a free tile next to the foe (hazard_tossed_weapon) and
-- its cell is empty until the thrower walks over it (Combat.itemBlockReason's `tossed`). The fight's end
-- hands it back by simply ending: the mark is kept on the unit, never on the character.
--
-- So any weapon becomes a ranged opener that costs a walk. The Cutter carries it beside an axe and does what
-- the approved body did -- distance does not stop it, but the rage costs it the weapon.
local Combat -- lazy: combat.lua loads the item registry

local function thrown(user)
    return (user and user.tossed) or {}
end

-- The weapon beside this Toss that is still in hand: the heaviest-hitting one, so a Cutter with a spear and
-- an axe beside it throws the axe it would rather lose less.
local function throwable(fx)
    Combat = Combat or require("models.combat")
    local best, bestAmount
    for _, it in ipairs(fx.adjacentItems() or {}) do
        local ab = it.type == "weapon" and it.activeAbility
        if ab and not thrown(fx.user)[it] then
            local amount = Combat.abilityMagnitude(ab) or 0
            if not bestAmount or amount > bestAmount then best, bestAmount = it, amount end
        end
    end
    return best, bestAmount
end

return {
    name = "Toss",
    description = "Throws the weapon beside it at a foe for that weapon's damage. It lands by the foe; walk over it to take it back.",
    flavor = "It was going to hit you with it either way. This way it did not have to walk over first.",
    sprite = "assets/items/ability_toss.png",
    type = "ability",
    tags = { "physical", "ranged" },
    class = "skirmisher",
    unlockLevel = 7,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2, -- a throw, not a swing: anything closer is what the weapon is for
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        requiresAdjacent = { type = "weapon" },
        effect = function(fx)
            local target = fx.target
            if not (target and target.alive) then return end
            local weapon, amount = throwable(fx)
            if not weapon then return end
            local tags = { "physical", "ranged" }
            for _, t in ipairs(weapon.tags or {}) do
                if t == "slash" or t == "pierce" or t == "impact" then tags[#tags + 1] = t end
            end
            fx.damage(target, { amount = amount, tags = tags })
            local x, y = fx.openTileNear(target.x, target.y)
            if type(x) == "table" then x, y = x.x, x.y end
            if not (x and y) then x, y = target.x, target.y end
            local pile = fx.placeHazard(x, y, "hazard_tossed_weapon", { owner = fx.user, side = fx.user.side })
            if pile then
                pile.item, pile.thrower = weapon, fx.user
                local held = {}
                for k, v in pairs(thrown(fx.user)) do held[k] = v end
                held[weapon] = pile
                fx.bank("tossed", held)
            end
        end,
    },
}
