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
-- The greatsword's wind-up is not a tax here, it is the characterisation. The family owes one
-- (docs/weapons.md; enforced by tests/weapon_spec.lua) and hers is the whole idea: declare the blow a
-- turn early, commit, land once. It also means the turns she spends winding up are turns she is NOT
-- feeding Ira, which is the right answer and the board teaches it without a word.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. The
-- signature convention (compare data/items/armor/armor_sworn_aegis.lua). `class = "fighter"` with no
-- `price`: unbuyable, and still tallying toward fighter growth (docs/classes.md).
--
-- Patience is also a knob the player turns, not only a sum the arithmetic does for her: she may HOLD
-- the wind-up longer for more (`windup`, below). Each tick she pours in past her floor lands as more
-- damage, and a deeper wind-up is a longer, breakable tell -- hard control or a shove shatters a
-- wind-up in progress and wastes the whole swing (Combat.interruptChannel), and every extra tick is a
-- turn her foes get to walk out of reach. The reward is for holding the edge exactly as long as the
-- board lets her. The depth is chosen at cast (wheel / + - / bumpers, states/battle.lua) and travels
-- with the networked command (models/command.lua) so both duellists resolve the same blow;
-- Combat.useItem clamps it to the range.
return {
    name = "The First Motion",
    description = "Channeled: Increase damage by up to +60% against a full-health foe.",
    flavor = "A bout is won in the first exchange or not at all. Everything she loves about the " ..
        "craft is folded into that one sentence.",
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
        description = "Increase damage the longer the wind-up is held, up to +60% against a full-health foe.",
        target = "tile",       -- aim an adjacent tile: it sets the facing the blow drives along
        allowOccupied = true,
        range = 1,
        minRange = 1,
        -- The FOLLOW-THROUGH: what the swing bills once it lands, and what she spends recovering from
        -- it. Down from 6, on every copy of the blade rather than a boss-only variant -- a greatsword
        -- that told for four ticks and then stood in its own recovery for six more was acting once
        -- every two or three of anyone else's turns, which read as a weapon that does not work rather
        -- than a weapon that costs something. The wind-up is where this blade's price is paid; the
        -- recovery was charging for it twice.
        speed = 4,
        -- The wind-up, in TOTAL ticks, and she chooses where in the range to loose it. `min` is the
        -- floor -- a signature swing is always a real commitment, never a poke -- and `max` the
        -- deepest hold. (Combat.useItem clamps to [min, max]; states/battle.lua opens at min and
        -- previews the resolve slot for the chosen depth on the turn-order strip.)
        --
        -- These are the numbers the file always APPEARED to say. They used to sit on top of a
        -- separate `channel = 2`, so "2 to 5" really meant a four-to-seven-tick tell and only the
        -- 2-to-5 part was paid for in damage -- the base was a tax that scaled nothing. The two
        -- fields are one now (models/item.lua's Item.windupRange), and making the range literal
        -- halves her floor: she commits for two ticks, not four.
        windup = { min = 2, max = 5 },
        -- THE BODIES UNDER THE BLADE FLINCH. On commit, whoever is already standing in the tiles the
        -- swing is telegraphed to sweep is made to Cower (data/status/cowering.lua) -- so the tell is
        -- not just information, it is a grip on the ones it is aimed at.
        --
        -- This is the answer to the blow being trivially dodgeable, and it deliberately does NOT make
        -- it undodgeable: Cowering cuts how FAR a step can carry you rather than forbidding the step.
        -- Standing in the strike zone when a greatsword is coming down is still the wrong idea; a
        -- cowering body moves too few tiles to clear the whole telegraphed footprint in one go. The
        -- counterplay moves from "take one step" to "be somewhere else before she commits" -- the read
        -- the weapon wanted all along.
        --
        -- A status on the bodies, NOT terrain: it lands once, on whoever is caught at the moment of
        -- commit, and a foe already clear of the footprint is never touched. That is the whole seam
        -- between her ground game and the house's -- the trappers PIN a runner outright with their
        -- bolas (character_trapper's Root); her own swing only makes the ones under it give ground.
        --
        -- The flinch lasts exactly as long as the swing hangs overhead: it is LIFTED the moment she
        -- stops channeling and the blow lands (Combat.resolveChannel), because there is no longer an
        -- incoming swing to cower from -- keeping foes crippled after the blow already fell would punish
        -- them twice for one telegraph. Being cut down mid-wind-up does NOT lift it, though: an interrupt
        -- leaves the fear on the body (tests/saber_debut_spec.lua), where it rides the wind-up's own
        -- length by default and fades on its own. Side-agnostic, as an unowned zone would have been --
        -- if an ally is somehow standing in the strike zone, it cowers too.
        channelAfflict = { status = "status_cowering" },
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
                -- Patience made arithmetic she controls: each wind-up tick she chose to hold BEYOND her
                -- floor adds a share of the swing (fx.held, from Combat.useItem's channel branch --
                -- fx.windup beside it is the total tell, which is not what is being paid for here).
                -- A swing loosed at the floor is an ordinary heavy greatsword blow; a deep hold into a
                -- fresh target is devastating. Reading `held` rather than the total is what makes the
                -- bonus the reward for a CHOICE: the two ticks she always pays are the price of the
                -- weapon, and only what she adds on top of them is patience.
                local held = math.floor(fx.amount * 0.4 * (fx.held or 0))
                fx.damage(u, { amount = fx.amount + opening + held })
            end
        end,
    },
}
