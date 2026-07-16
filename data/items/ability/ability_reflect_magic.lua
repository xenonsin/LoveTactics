-- Reflect Magic: lay a mirror on yourself or a nearby ally. For the window, single-target spells aimed
-- at them rebound onto the caster who threw them (data/status/reflect_magic.lua).
--
-- The mage's third answer to magic, and the one that punishes rather than survives. The shelf now
-- reads as a genuine choice rather than a ladder:
--   * Magical Barrier -- eats one spell, cheap, long window. The economical answer.
--   * Counter Magic   -- unravels one spell for nothing, on a reflex, at a mana price and a cooldown.
--   * Reflect Magic   -- answers EVERY single-target spell in the window, and bills the caster for it.
-- Each is better than the others somewhere: the barrier against one big hit you see coming, the
-- counter against a spell you don't, the mirror against a mage that has committed to a target.
--
-- Priced as the greedy one: it costs more than a barrier, lands slower (speed 8), and buys a window
-- rather than a certainty. Against a foe who then declines to cast at it, it bought nothing at all --
-- which is exactly the bluff the ward is for.
return {
    name = "Reflect Magic",
    description = "Mirror an ally for a time: single-target spells rebound onto the caster.",
    sprite = "assets/items/ability_reflect_magic.png",
    type = "ability",
    tags = { "arcane", "protective" },
    class = "mage",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "ally", -- includes the caster (a unit is its own ally)
        support = true,
        range = 2,
        speed = 8,
        cost = { stat = "mana", amount = 22 },
        effect = function(fx)
            fx.applyStatus(fx.target, "reflect_magic")
        end,
    },
}
