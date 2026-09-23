-- A WHIRL ELEMENTAL: the Lust circle's fourth elite, the two things the keep made meeting each other,
-- and the only body on the stratum whose rule is two rules that need each other.
--
-- A FIRE CLIMBS BECAUSE IT DRAGS AIR IN BEHIND IT. That is the entire blueprint, and it is why this
-- body exists rather than a bigger Fire Elemental and a bigger Wind Elemental. Its haul takes a BURNING
-- foe the whole length of the room and a cold one a single stumbling tile
-- (data/items/weapon/weapon_chimney_draw.lua); its answer to a melee blow sets fire to everything
-- standing next to it (data/traits/trait_backdraught.lua). So the fire is what the wind has to pull on,
-- and the wind is what makes the fire worth having lit. Neither half is a threat alone and the loop
-- arms itself off the company's own first exchange: walk up, swing, your rank is alight, and the next
-- thing this body does is use that.
--
-- IT IS THE ONLY ONE OF THE THREE NOBODY CONJURES. Fire and wind are Arcanum summons as well as rift
-- bodies (character_fire_elemental carries that argument); there is no `ability_summon_whirl_elemental`
-- and there should not be. This is what those two become when they are left in a building together for
-- a few hundred years, and a summoner calling one would be calling the Cathedral's whole accident.
--
-- AND IT SCATTERS FIRE AS IT GOES, which is deliberately NOT the Fire Elemental's trail. That one lays
-- a print behind it -- a line, legible, avoidable, and a corridor closed on purpose
-- (data/items/utility/utility_living_flame.lua). This throws fire into the room around itself as it
-- moves (`trail.scatter`, Combat.layTrail): one tile at a time, somewhere within two of where it just
-- was, never predictably. The difference is the whole difference between the chaff and the alpha --
-- a company can plan around a line and cannot plan around a room slowly catching. It is also how the
-- haul below stays armed without the body having to spend a turn on it.
--
-- WHICH IS WHAT AN ELITE ON THIS GROUND IS FOR. The Eyrie takes away the choice of where to stand, the
-- Drowned Stair prices every tile you move, the Lady Chapel takes the SWING. This takes the OPENING --
-- the company's ordinary way into a fight is the thing that arms it, and working that out is the fight.
-- Four elites, four different things confiscated, which is the stratum's whole method.
--
-- AND THE ESCORT IS THE FUEL LINE, NOT AN HONOUR GUARD. A Fire Elemental bills every blow the party
-- throws (data/characters/character_fire_elemental.lua), and every burn it hands out is a handhold this
-- body did not have to make for itself. That makes the Flue the one fight on this stratum where
-- clearing the chaff first is the correct opening rather than the trap it is everywhere else in the
-- circle -- a deliberate inversion of the law the Long Gallery and the Lady Chapel spent two floors
-- teaching. Cut the one doing it has an exception, and this is it, and the exception is legible from
-- the board.
--
-- THE COUNTERPLAY, STATED, because an elite whose rule cannot be answered is a tax. Cure the burn and
-- the haul is a stumble. Kill the lamps and it has nothing to pull with. Answer it at reach and never
-- light yourself on it. Or take the haul on purpose, with a body that wanted to be next to it anyway,
-- and let it spend its turn re-arranging somebody who was coming regardless. Four keys, all of them
-- things a company already carries -- the standard the Lady Chapel set.
--
-- FOOTPRINT 1x1, on the Matriarch's reasoning and for the same board. The Thinwall Keep is a warren of
-- doorways and a two-by-two body cannot use one; an apex that the carve keeps in a single room would be
-- an apex whose every rule is about hauling people across rooms.
--
-- A THIRD ELITE THAT IS NOT A THIRD ANIMAL, and billed nowhere. Descent.SINS bills this circle's two
-- rungs to its two original animals on purpose -- the coils hold the approach and the wings hold the
-- seat, cheapest rule first -- and that argument is not worth unpicking to seat a fourth. The Flue turns
-- up at ELITE_WEIGHT on either floor beside the Lady Chapel (Descent.floorPool's elite branch keeps the
-- unnamed ones legal), which is the right rarity for the thing that is not what the stratum is ABOUT
-- but is the worst thing standing in it.
--
-- Tier 3's band is 81-154 health (Balance.HEALTH_BANDS). Beside the Matriarch on purpose: the two are
-- this circle's standing elites in its two elements and a company should not be able to tell from the
-- health bar which of them it has walked into.
return {
    name = "Whirl Elemental",
    race = "elemental",
    tier = 3,
    sprite = "assets/chars/whirl_elemental.png",
    stats = {
        health = 118, mana = 0, stamina = 28,
        staminaRegen = 3,
        damage = 15, magicDamage = 15,
        defense = 8, magicDefense = 13,
        movement = 5,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 6,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The same flame as the lamp rooms, with a chimney's worth of air under it.
    --   And the same answer: it is a fire. Take the air away, or put it out.
    resist = { fire = 4, slash = 4, impact = -4, water = -8, ice = -8 },
    -- The Gyre is the third hand and the wild one: it goes where the wind puts it, cutting every body it
    -- passes over (data/items/weapon/weapon_gyre.lua). A body that keeps moving is a body scattering
    -- fire, so a rush it did not choose still lays the room alight on the way.
    startingItems = { "weapon_chimney_draw", "weapon_flashover", "weapon_gyre", "utility_flue_throat" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md): the combination, which is the only thing on this floor that
    -- is neither the fire nor the wind. Its escort's drop is listed second, so a company that already
    -- holds the Flame is paid the lamp's bill instead of nothing (Descent.dropFor walks the list and
    -- skips what you hold) -- the Matriarch's arrangement with her own flock, exactly.
    -- The Whirlwind follows it: the Gyre learned, the body's own trick taken off the thing that used it
    -- on you, and on no counter anywhere (data/items/ability/ability_whirlwind.lua).
    drops = {
        "utility_the_climbing_flame",
        "ability_whirlwind",
        "utility_the_answered_wish",
    },
    -- The flashover rather than the draw: `defaultAction` is what a compulsion and a counter swing
    -- (models/ai.lua), and what this body does to something already standing against it is light it.
    -- The planner reaches for the Chimney-Draw on its own, on that weapon's own `ai` clause.
    defaultAction = "weapon_flashover",
    -- `aggressive` where the flock skirmishes, and it is the plainest statement of the difference: a
    -- harpy wants the gap and this wants bodies at its feet, because bodies at its feet are what both
    -- of its rules are written about -- and because a body that keeps moving is a body scattering fire.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
