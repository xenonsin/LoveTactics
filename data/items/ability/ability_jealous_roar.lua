-- JEALOUS ROAR: the Green-Eyed Monster's trophy (data/characters/character_green_eyed_monster.lua), on the
-- Barbarian's shelf. Approved on "Envy's Bestiary", round 2. The roar in a company's throat: every foe within 2 of
-- the bearer is shoved 2 tiles straight away from its nearest ally, so a line that stood shoulder to shoulder is
-- standing alone. A foe with no ally left on the field has nobody to be parted from and stays where it is.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Jealous Roar",
    description = "Every foe within 2 is shoved 2 tiles away from its nearest ally.",
    flavor = "A barbarian's war cry says come here. This one says get away from each other, which works better.",
    sprite = "assets/items/ability_jealous_roar.png",
    type = "ability",
    tags = { "fear" },
    class = "barbarian",
    unlockLevel = 11,
    unstocked = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        cooldown = 10,
        support = false, -- a shove into the foe: hostile, though it lands no damage of its own
        cost = { stat = "stamina", amount = 10 },
        aoe = { radius = 2, shape = "diamond" },
        effect = function(fx)
            local Envy = require("models.envy_oneoffs")
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive and u.side ~= fx.user.side then
                    local ally = fx.combat and fx.combat.units and Envy.nearestAlly(fx.combat, u)
                    local dest = ally and Envy.awayFrom(u, ally, 2)
                    if dest then fx.knockback(u, 2, { dest = dest }) end
                end
            end
        end,
    },
}
