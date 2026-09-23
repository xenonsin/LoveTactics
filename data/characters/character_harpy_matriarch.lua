-- A HARPY MATRIARCH: the same bird, grown into the rule the flock only gestures at.
--
-- THE ESCALATION IS EXACT, AND IT IS THE CIRCLE'S OWN SHAPE. A harpy moves ONE body ONE tile and hopes
-- the room does the rest. She moves the room:
--
--   the flock   the talons haul one foe in from two tiles; the gust beats one foe back a tile.
--               Both are DISPLACEMENT: they decide where your body is.
--   the alpha   the same two, plus a cry that decides what your body DOES -- Taunt and Burn at four
--               tiles, so the victim spends its own turns walking to her and pays for every one of
--               them (weapon_the_wanting) -- plus a wing-beat that throws EVERYTHING adjacent off her
--               when she is struck (trait_downdraft).
--
-- SO SHE ESCALATES IN KIND, NOT IN SIZE, and that is the whole of what separates an alpha from a
-- bigger piece of chaff. Four harpies are a furniture-moving problem. She is the reason you cannot
-- solve it by standing somewhere sensible, because she takes the standing-somewhere away from you.
--
-- HER FIGHT IS A TIDE, AND THE TIDE IS THE POINT. The cry compels a body toward her; the Downdraft
-- throws it back off the moment it swings; the burn runs the whole time it is crossing the floor
-- again. A company that plays her fight on her terms spends every turn walking and never lands a
-- second blow from the same tile.
--
-- THE ANSWER IS THE TAUNTER, and it is the same answer this circle's other control effect has always
-- had: the jeer dies with the jeerer (status_taunt's onTick -- cut her down and everyone she was
-- holding is handed straight back, mid-turn). So her fight is a race between what the compulsion
-- costs the company per turn and how fast the bodies she has NOT called can reach her. Which is why
-- the flock matters: every harpy shoving a free body a tile further off is a turn added to that race.
--
-- NOT A BOSS. `boss = true` means an assassinate mark and nothing else (docs/bestiary.md), and she is
-- an elite -- the discipline stated, not a quest's conclusion. So she is Charmable, Polymorphable and
-- open to a finisher, which is correct: this circle spends the whole floor taking bodies, and the one
-- body it would be sweetest to take had better be takeable.
--
-- WHAT SHE IS, IN THE FICTION. The blooding that took wrong and then went on taking (docs/story.md).
-- The flock in the keep is hers -- every harpy on the floor came out of the same rite, and she is the
-- one that lived long enough to learn what the singing was for.
--
-- Tier 3's band is 81-154 health (Balance.HEALTH_BANDS). Middle of it: she is not hard to hurt, she is
-- hard to STAND NEXT TO, and a body priced on position needs enough health to be worth out-positioning.
return {
    name = "Harpy Matriarch",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/harpy_matriarch.png",
    stats = {
        health = 112, mana = 44, stamina = 26,
        staminaRegen = 3,
        damage = 15, magicDamage = 14,
        defense = 8, magicDefense = 12,
        movement = 6,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 9, luck = 7,
    },
    -- FOOTPRINT 1x1, deliberately, where an apex on open ground would take four tiles. The Thinwall
    -- Keep is a warren of doorways and a two-by-two body cannot use one -- she would be an alpha that
    -- the board keeps in a single room, and every rule she has is about crossing rooms.
    --
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The same feathers as the flock, laid deeper, and an edge finds even less of a seam in them.
    --   The same hollow behind them. What goes between them goes a long way in.
    resist = { slash = 4, pierce = -4, fire = 4, holy = -8 },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), and it is the cry rather than the wing-beat. Downdraft
    -- would have been a third copy of a reflex the game already sells twice (Shield Shove, Antler
    -- Toss); the Taunt-and-Burn couple is hers alone and is the thing a player actually remembers
    -- about this fight. Handed over as the COUPLING rather than the cast, so it pays off whatever
    -- taunt the company already carries -- including the two Sentinel armours that pointed at nobody
    -- until the stamp moved into the status.
    --
    -- Her flock's drop is listed second, so a company that already holds the charm is paid the wind
    -- instead of nothing (Descent.dropFor walks the list and skips what you hold).
    drops = {
        "utility_coalsong",
        "utility_the_updraught",
    },
    startingItems = { "weapon_harpy_talons", "weapon_stooping_gust", "weapon_the_wanting",
                      "utility_flight_feathers" },
    defaultAction = "weapon_harpy_talons",
    archetype = "skirmish",
    ai = {
        -- SHE REACHES PAST THE FRONT RANK FOR WHOEVER IS ALREADY GIVING WAY. `nearest` -- the default
        -- every body on this ground carries -- would have her cry at whatever is standing in her face,
        -- and a pull that moves a body one tile is the one version of this fight that is not a fight.
        -- Dragging the company's weakest into the middle of the flock is what makes the cry cost a
        -- formation rather than a step. The Barrow Lord's rule, for a related reason: what matters is
        -- not the wound, it is WHERE the body ends up.
        --
        -- (`lowest_hp` and not some reading of distance: AI.TARGET_PREF_ORDER is the whole list of
        -- preferences the planner implements, and a field it does not know is a field that scores
        -- zero in silence.)
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
