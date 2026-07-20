-- Saber's signature, and the counterplay to Ira written as arithmetic (docs/story.md, "The Colosseum").
--
-- > Ira scales as her own health falls. Saber scales with her target's.
--
-- The two of them are opposed on the same axis, and every bout from the debut onward is teaching the
-- player the lesson the general will examine them on. Ira wants a long trade, because every blow
-- wakes her up (data/traits/trait_wrath_rising.lua). This blade is worthless in a long trade and
-- devastating on the opening. Grind, and you lose twice over: she gets stronger and you get weaker.
--
-- THE VIRTUE IS A VERB, NOT AN ABSENCE. The obvious way to build patience is to bank a bonus for
-- turns spent not attacking -- and that is downtime, not patience, and it is not fun. Sitting still
-- is what Ira's victims do. Saber's patience is the discipline to pick the moment and commit to it,
-- so the reward is for READING the board (who is fresh, who is worth the wind-up) rather than for
-- abstaining from it. There is never a turn where the correct play is to do nothing.
--
-- The bonus is upside, never a penalty: the base damage array is a full greatsword's, so a swing into
-- a wounded target is an ordinary heavy hit rather than a punishment. She simply pays off enormously
-- for opening a fight instead of closing one -- the opposite of every other greatsword in the game.
--
-- The greatsword's `channel` is not a tax here, it is the characterisation. The family owes a wind-up
-- (docs/weapons.md; enforced by tests/weapon_spec.lua) and hers is the whole idea: declare the blow a
-- turn early, commit, land once. It also means the turns she spends winding up are turns she is NOT
-- feeding Ira, which is the right answer and the board teaches it without a word.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. The
-- signature convention (compare data/items/armor/armor_sworn_aegis.lua). `class = "fighter"` with no
-- `price`: unbuyable, and still tallying toward fighter growth (docs/classes.md).
--
-- Her SECOND relic, late in the line, removes the falloff for one strike per battle at a moment the
-- player chooses -- patience becoming a choice of when rather than a sum the arithmetic does for her.
-- That one is unwritten.
return {
    name = "The First Motion",
    description = "Winds up, then lands. Hits hardest against a target at full health.",
    flavor = "She was taught that a bout is won in the first exchange or not at all. It is the only " ..
        "thing they taught her that she kept.",
    sprite = "assets/items/first_motion.png",
    type = "weapon",
    -- Its own archetype, NOT the sword family (docs/weapons.md): a greatsword's verb is the wind-up,
    -- and it must not inherit the sword's Parry. Saber does not answer blows -- answering is Ira's
    -- mode, and the whole point of this weapon is that it acts first.
    tags = { "greatsword", "slash", "physical", "melee", "signature" },
    hands = 2,
    bound = true,
    class = "fighter",
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the facing the blow falls on
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 6,             -- ponderous, but a shade quicker than an iron greatsword
        channel = 1,           -- winds up one turn before it lands; hard control breaks the wind-up
        cost = { stat = "stamina", amount = 15 },
        damage = { 22, 24, 27, 29, 32, 34, 37, 39, 42, 44, 47 },
        effect = function(fx)
            if not fx.target then return end
            -- The opening: what the blow gains for finding its target whole. Read at the moment the
            -- wind-up LANDS, not when it started -- so a foe who was healed out of danger while she
            -- committed is worth more, and one the party softened in the meantime is worth less.
            -- Taken off fx.amount rather than a flat number, so it climbs with the forge as the base
            -- swing does.
            local hp = fx.target.char.stats.health
            local frac = (hp.max and hp.max > 0) and ((hp.current or 0) / hp.max) or 1
            local opening = math.floor(fx.amount * 0.6 * frac)
            fx.damage(fx.target, { amount = fx.amount + opening })
        end,
    },
}
