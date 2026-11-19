-- Springwater: the Nymph's one kindness, and it is a kindness with legs -- a heal, and a turn of Haste
-- so the body she mended can get out of where it was being mended.
--
-- She is a spring before she is anything else, and a spring that only healed would make her the second
-- priest on a floor that already has a honey field. The Haste is what makes it hers: it is mobility
-- handed across, which is the Dryad line's whole claim, and one turn of it is about a step's worth.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
--
-- THE SPRING RISES WITH THE GROVE (2026-11-19, the creature identity pass). The audit found the Nymph a
-- caster with "little readable threat" -- four spells and nothing on the board to answer. So the heal is
-- now counted off the plants of her side standing on the board (Grove.isPlant: her saplings, a Mandrake,
-- a Heartwood Tree): 3 for each, plus the level. One sapling heals what the flat 6 used to; none heals
-- almost nothing; a grove of three makes her very hard to finish. The answer is a thing you can see and
-- reach -- cut the plants first -- and it is the same answer Greenstep already asked, since she can only
-- step between plants that are standing.
local PER_PLANT = 3

local function plantsOf(combat, side)
    local Grove = require("models.grove")
    local n = 0
    for _, u in ipairs((combat and combat.units) or {}) do
        if Grove.isPlant(u) and u.side == side then n = n + 1 end
    end
    return n
end

return {
    name = "Springwater",
    description = "Heals an ally 3 for each plant on her side, and Hastes it for a turn.",
    flavor = "Cold, clear, and moving. It does not stay where it is put, and it would rather you didn't either.",
    sprite = "assets/items/springwater.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "water", "magical", "restorative" },
    noSteal = true,
    activeAbility = {
        target = "ally",
        range = 3,
        speed = 4,
        support = true,
        cost = { stat = "mana", amount = 8 },
        ai = {
            { priority = "high", act = "support", targetPref = "most_wounded",
              when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.6 } },
        },
        effect = function(fx)
            fx.heal(fx.target, PER_PLANT * plantsOf(fx.combat, fx.user.side) + fx.level)
            fx.applyStatus(fx.target, "status_hasted", { duration = 6 })
        end,
    },
}
