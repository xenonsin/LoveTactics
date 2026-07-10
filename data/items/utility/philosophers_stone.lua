-- Crucible rank-4. It has no power of its own. Point it at a foe and it makes another of them,
-- standing beside you, fighting for you -- and dying to the first thing that touches it (`fragile`).
-- Everything it can do, it does by wanting what something else already is.
--
-- Set beside the Arcanum's Doppelganger (data/items/ability/ability_doppelganger.lua), the shelf tells
-- the whole story of two sins: a mage copies ITSELF, which is Pride, and the Codex of Hubris is a tome
-- that reads its bearer back. An alchemist copies SOMEONE ELSE, which is Envy. Same mechanic, opposite
-- appetite. `noCopy`, so neither one can be used to make more of itself.
--
-- The Crucible sells nothing it made -- the first hint of Envy, whose general has no shape until it
-- has seen yours. It will point this very ability at your strongest, and it will not be fragile then.
return {
    name = "Philosopher's Stone",
    description = "Conjure a duplicate of an enemy, fighting for you. It dies to a single hit.",
    sprite = "assets/items/philosophers_stone.png",
    type = "utility",
    tags = { "arcane", "illusion" },
    class = "alchemist",
    price = 800,
    repRank = 4,
    noCopy = true,
    activeAbility = {
        name = "Transmute",
        target = "enemy",
        range = 3,
        requiresSight = true, -- you cannot covet what you cannot see
        speed = 6,
        cost = { stat = "mana", amount = 24 },
        effect = function(fx)
            -- The shape is set down beside its caster, not beside the foe it was lifted from. Hemmed
            -- in on all eight sides, there is nowhere to put it: the cast is spent and nothing comes.
            local x, y = fx.openTileNear(fx.user.x, fx.user.y)
            if not x then
                fx.log("system", string.format("%s has no room to set the shape down.",
                    fx.user.char.name or "Unit"))
                return
            end
            fx.copyOf(fx.target, x, y, { fragile = true })
        end,
    },
}
