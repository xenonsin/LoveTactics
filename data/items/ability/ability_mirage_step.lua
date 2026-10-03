-- MIRAGE STEP: the Mirage's trophy (data/characters/character_mirage.lua), on the Ninja's shelf. Approved on
-- "Envy's Bestiary", round 1. The trick turned around: the caster leaves an illusion of itself on the tile it
-- stood on and blinks up to 3 away. The illusion is the Decoy's double (fx.copy, `fragile`, holding position), so
-- a foe that swings at it fells it, and the swing is gone.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Mirage Step",
    description = "Leave an illusion on your tile and blink 3 tiles. A foe that targets the illusion wastes its action.",
    flavor = "The ninja's whole art is being somewhere else. This is being somewhere else twice.",
    sprite = "assets/items/ability_mirage_step.png",
    type = "ability",
    tags = { "illusion", "movement" },
    class = "ninja",
    unlockLevel = 11,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 3,
        support = true,
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            local fromX, fromY = fx.user.x, fx.user.y
            if not fx.teleportUser(fx.tx, fx.ty) then return end
            -- Planted on the tile just left, once it is empty: the double stands where the caster was seen.
            fx.copy(fromX, fromY, { fragile = true, control = "none", decoy = true })
        end,
    },
}
