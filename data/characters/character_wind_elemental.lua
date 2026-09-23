-- A WIND ELEMENTAL: the Lust circle's fifth animal, the other half of what the rite left in the
-- building, the only body on the stratum the stratum cannot move -- and, since it took this id, what an
-- Arcanum summoner calls.
--
-- ONE BLUEPRINT, TWO ROLES. The argument is character_fire_elemental's and is made there in full: a
-- body used as both cargo and combatant has to be split, and this is not that -- there are no
-- placeholder pools here being read as a stat block. What IS true, and is worth an author knowing
-- before they price anything against it, is that this one did not carry the conjuration's numbers
-- across the way the fire did. The old wind elemental was a tier-1 scout: 16 health, a pair of Gale
-- Fists and nothing else. This is a tier-2 line body with reach, a three-tile shove and a stance
-- nothing shifts. **`ability_summon_wind_elemental` therefore fields a considerably stronger
-- conjuration than it was priced for**, and its cost and reservation have not been revisited. That is a
-- deliberate, recorded debt rather than an accident.
--
-- WHAT IT IS, IN THE FICTION. The blooding burns something out of a body and what it drives out stays
-- in the keep (character_fire_elemental carries the whole argument). The heat settled in the lamp
-- rooms. The breath went up the stair and into the bell loft, and it has been ringing a bell nobody is
-- pulling ever since -- which is the sound the Cathedral tells the city is the hour.
--
-- IT IS THE CIRCLE'S THESIS AT ITS LOUDEST. models/descent.lua says this stratum does not kill a
-- company, it rearranges one, and the Thinwall Keep does the killing: Combat.knockback bills the impact
-- of every tile a shove could not spend, and this shoves THREE. A harpy's gust takes a body out of a
-- rank; a bellstroke takes it out of the ROOM -- through the doorway its line was holding, into
-- whatever the next chamber has in it, with the healer on the wrong side of a wall
-- (data/items/weapon/weapon_bellstroke.lua). Almost none of the damage on the readout came from this
-- body and all of it was this body's doing.
--
-- AND NOTHING HOLDS IT, WHICH IS WHERE THE CIRCLE MEETS SOMETHING IT HAS NOTHING TO SAY TO. It wears
-- Unheld from the opening bell (data/traits/trait_nothing_to_hold.lua): a lamia's coil closes on a
-- draught and shuts on itself, the Matriarch's wing-beat throws everything adjacent except this, and a
-- company's own mace, hook, charge and Gaff Line all answer it with nothing. The floor's animals were
-- never additive -- the lamia's header already argues that being held is shelter from the flock -- and
-- this is that argument taken to its end: a body standing outside the entire conversation about where
-- anybody is.
--
-- SO THE LESSON IS THE ONE THE STRATUM HAS NEVER HAD TO TEACH. Everything else here is answered by
-- choosing your ground. This is answered by hitting it, and a company that has spent two floors
-- learning to solve rooms by standing in the right part of them arrives at the bell loft with the wrong
-- instinct and no way to use it.
--
-- IT KEEPS THE FISTS, which is the conjuration's half left intact rather than replaced. `skirmish`
-- holds the gap the bellstroke is written for -- three tiles, the harpy's own reach and for the harpy's
-- own reason -- and the Gale Fists are what happens to whoever closes anyway. A body with only the
-- reach weapon would be answered by walking at it.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS). Low in it -- thin, fast and reaching, on the
-- harpy's own numbers, because the two are the same verb at two scales and should die at the same rate.
return {
    name = "Wind Elemental",
    race = "elemental",
    tier = 2,
    sprite = "assets/chars/wind_elemental.png",
    stats = {
        health = 44, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 10, magicDamage = 10,
        defense = 3, magicDefense = 9,
        movement = 6, -- it keeps the length of the hall between itself and whoever is crossing it
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 8,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   There is nothing in it to cut and nothing in it to skewer, which is most of a rack gone.
    --   A shockwave is the one thing that moves air, and moving air is the whole of what this is.
    resist = { slash = 3, pierce = 3, impact = -6, lightning = -4 },
    startingItems = { "weapon_bellstroke", "weapon_gale_fists", "utility_moving_air" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md). The stance rather than the stroke -- a third shove handed to
    -- the player would be the flock's Updraught with a bigger number on it, and what a company actually
    -- remembers about a bell loft is the thing it could not move. The rift sells you the trick.
    drops = {
        "utility_the_unheld",
    },
    -- The fists rather than the stroke: `defaultAction` is what a compulsion and a counter swing
    -- (models/ai.lua), and what this body does to something already standing against it is hit it. The
    -- planner reaches for the bellstroke on its own whenever the gap is worth opening.
    defaultAction = "weapon_gale_fists",
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
