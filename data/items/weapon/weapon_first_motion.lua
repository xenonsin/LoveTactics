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
-- Patience is also a knob the player turns, not only a sum the arithmetic does for her: she may HOLD
-- the wind-up longer for more (`windup`, below). Each extra tick she pours in lands as more damage,
-- and a deeper wind-up is a longer, breakable tell -- hard control or a shove shatters a channel and
-- wastes the whole swing (Combat.interruptChannel), and every extra tick is a turn her foes get to walk
-- out of reach. The reward is for holding the edge exactly as long as the board lets her. The depth is
-- chosen at cast (wheel / + - / bumpers, states/battle.lua) and travels with the networked command
-- (models/command.lua) so both duellists resolve the same blow; Combat.useItem clamps it to windup.max.
return {
    name = "The First Motion",
    description = "Winds up, drives through the tiles in front (a cone when forged). Bonus scales to +60% into a full-health foe.",
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
        description = "Hold the wind-up longer to strike harder; the health bonus scales to +60% of the swing against a full-health foe.",
        target = "tile",       -- aim an adjacent tile: it sets the facing the blow drives along
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 6,             -- ponderous, but a shade quicker than an iron greatsword
        channel = 2,           -- the BASE wind-up: two ticks before it lands; hard control breaks it
        -- ...and she pours between two and five MORE ticks in, chosen at cast, for more damage. The
        -- `min` is the floor: a signature swing is always a real commitment, never the bare base -- she
        -- cannot loose it below +2. (Combat.useItem clamps to [min, max]; states/battle.lua opens at min
        -- and previews the resolve slot for the chosen depth on the turn-order strip.)
        windup = { min = 2, max = 5 },
        cost = { stat = "stamina", amount = 15 },
        damage = { 22, 24, 27, 29, 32, 34, 37, 39, 42, 44, 47 },
        -- The overhead blow doesn't stop at the first body: it drives THROUGH the tiles in front (the
        -- aimed cell tx,ty and the ones beyond it), and the follow-through WIDENS as the blade is forged.
        -- Both fields are per-level lists (models/item.lua bakes in this level's entry at instantiate, so
        -- the preview footprint and the effect's fx.aoeUnits read one shape):
        --   * levels 0-2: a straight line two tiles deep -- the aimed cell and the one behind it.
        --   * levels 3-5: the same line, now three tiles deep -- the reach lengthens.
        --   * levels 6-10: it OPENS INTO A CONE (Combat.aoeCells "cone"): a triangle three rows deep that
        --     fans one tile wider each step out, so a full-forge swing sweeps a whole wedge of the front.
        -- The reach number becomes the cone's DEPTH when the shape turns, and a depth-3 cone already
        -- sweeps far more tiles than the length-3 line it grew from -- coverage only ever climbs.
        -- Each body caught is scored on its OWN health below, so a fresh rank at the wide end of the
        -- cone is worth as much as a fresh target at the tip.
        aoe = {
            shape  = { "line", "line", "line", "line", "line", "line", "cone", "cone", "cone", "cone", "cone" },
            length = {   2,      2,      2,      3,      3,      3,      3,      3,      3,      3,      3    },
        },
        effect = function(fx)
            -- Every body the line passes through, near tile then far (fx.aoeUnits walks the footprint
            -- against the LIVE board, so a foe who stepped clear during the wind-up simply isn't there).
            for _, u in ipairs(fx.aoeUnits()) do
                -- The opening: what the blow gains for finding THIS target whole. Read at the moment the
                -- wind-up LANDS, not when it started -- so a foe healed out of danger while she committed
                -- is worth more, and one the party softened in the meantime is worth less. Taken off
                -- fx.amount rather than a flat number, so it climbs with the forge as the base swing does.
                local hp = u.char.stats.health
                local frac = (hp.max and hp.max > 0) and ((hp.current or 0) / hp.max) or 1
                local opening = math.floor(fx.amount * 0.6 * frac)
                -- Patience made arithmetic she controls: each extra wind-up tick she chose to hold adds a
                -- share of the swing (fx.windup, from Combat.useItem's channel branch). A snap swing is an
                -- ordinary heavy greatsword blow; a deep hold into a fresh target is devastating.
                local held = math.floor(fx.amount * 0.4 * (fx.windup or 0))
                fx.damage(u, { amount = fx.amount + opening + held })
            end
        end,
    },
}
