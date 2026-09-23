-- AN ELDER LAMIA: the same serpent, and the tether grown a slope.
--
-- THE ESCALATION IS THE SENTENCE REPEATED LOUDER, not a second sentence. A lamia's coil is a TOLL --
-- leave the circle, take a fixed bite, and a company that has decided the ground is worth it pays a
-- known price once a turn. Hers is a CURVE: every tile past the circle is worth another bite
-- (data/traits/trait_the_long_coil.lua). So the question stops being whether to leave and becomes how
-- far, which is a dial rather than a toll -- and a party that has been scattered across a keep by a
-- flock discovers it has been standing on her damage the whole time.
--
--   the flock   the talons haul one foe in, the gust drives one off. Where your body is.
--   the coils   the knot pins for a turn, the fang says leaving costs. That it is anywhere else.
--   the Elder   the same two, and the cost is now measured in tiles.
--
-- WHICH MAKES HER THE FLOOR'S ARTILLERY WITHOUT CARRYING A RANGED ATTACK. Every harpy on the board
-- delivers her damage for free the moment it shoves a coiled body, and every step the party takes to
-- reform its line is another rung. The deeper a Lust floor stacks its own roster the more she reads,
-- which is what an elite rung is for.
--
-- NOT A BOSS. `boss = true` means an assassinate mark and nothing else (docs/bestiary.md); she is the
-- discipline stated, not a quest's conclusion. So she is Charmable, Polymorphable and open to a
-- finisher -- correct on a stratum that spends its whole floor taking bodies.
--
-- AND THE TETHER DIES WITH HER, which is this circle's law rather than this body's mercy: a charm ends
-- with its charmer, a jeer with its taunter, a coil with the serpent. Cut the one doing it. She has
-- the health for that to be a real question and not much else -- what makes her dangerous is the board
-- her own line is arranging, so on clean ground with her escort down she is a slow animal with a bite.
--
-- Tier 3's band is 81-154 health (Balance.HEALTH_BANDS). Below the Matriarch's 112: she is easier to
-- reach and harder to leave, which is the pair those two make.
return {
    name = "Elder Lamia",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/elder_lamia.png",
    stats = {
        health = 104, mana = 0, stamina = 28,
        staminaRegen = 3,
        damage = 17, magicDamage = 0,
        defense = 11, magicDefense = 7,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 9, luck = 4,
    },
    -- FOOTPRINT 1x1, like the Matriarch and for the same reason: the Thinwall Keep is a warren of
    -- doorways and a two-by-two body cannot use one. A tether whose holder cannot follow you through a
    -- door is a tether the board answers for free.
    --
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The same scale as the young ones, laid deeper, and an edge slides further before it stops.
    --   The same soft length underneath. A weight still only has to land.
    resist = { slash = 4, impact = -4, fire = 4, holy = -8 },
    startingItems = { "weapon_strangleknot", "weapon_lunging_fang", "utility_serpents_length" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), and it is the slope rather than the string. The Lamia's
    -- own drop hands over a tether; this hands over what she does WITH one -- a blow that lands harder
    -- on anything already held. The two are a pair a player assembles out of one circle, which is the
    -- same shape Coalsong and the taunts make one ladder over.
    --
    -- Her line's drop is listed second, so a company that already holds the teeth is paid the string
    -- rather than nothing (Descent.dropFor walks the list and skips what you hold).
    drops = {
        "utility_constrictors_due",
        "utility_the_slow_circle",
    },
    defaultAction = "weapon_strangleknot",
    archetype = "aggressive",
    ai = {
        -- SHE PUTS THE STRING ON WHOEVER IS FURTHEST FROM HER TROUBLE. `lowest_hp` is the Matriarch's
        -- rule and it is the wrong one here: a body about to fall will not be paying a tether for
        -- long. What a coil wants is somebody who is going to be ALIVE and MOVING for the rest of the
        -- fight, and `nearest` picks that by default -- the front rank, which is the half of the
        -- company that has to keep stepping back to hold a line.
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
