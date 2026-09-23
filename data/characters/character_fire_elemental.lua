-- A FIRE ELEMENTAL: the Lust circle's fourth animal, the one that is not an animal, and -- since it
-- took this id -- the thing an Arcanum summoner calls as well.
--
-- ONE BLUEPRINT, TWO ROLES, AND THAT IS THE EXCEPTION RATHER THAN THE RULE. This folder records twice
-- that a body used as both cargo and combatant has to be SPLIT: the Dire Bear is a shape a hunter
-- WEARS, so its pools are placeholders and it stood on Gluttony's stair with one health; the Homunculus
-- is the alchemist's summon, so it stood on Envy's as tier-1 chaff (models/descent.lua says both at
-- length). This is not that. The numbers below ARE combat numbers -- they were the summon's, and they
-- have not moved -- so nothing here is a placeholder being read as a stat block. What the body gained
-- by coming out of the rift is two RULES, and a summoner gets them too.
--
-- THE THREE SIBLINGS DID NOT COME WITH IT. character_ice_elemental, _earth_, _lightning_ and _water_ are
-- still conjuration-only bodies with one natural weapon apiece. Fire and wind have a place they are
-- FROM now; the other four do not, and until they do the asymmetry is the honest state rather than an
-- oversight.
--
-- WHAT IT IS, IN THE FICTION, AND WHY THERE IS AN ELEMENTAL IN A KEEP AT ALL. The blooding takes a body
-- and burns something out of it (docs/story.md, "The blooding"). The harpies and the lamiae are the
-- rite gone wrong in two directions; the succubus line is the rite taken cleanly. This is the fourth
-- possibility and the one nobody in the Cathedral has ever had to think about: **what the rite drives
-- out does not go anywhere.** It stays in the building. The heat stands in the lamp rooms and the
-- draught stands in the bell loft (data/characters/character_wind_elemental.lua), and between them they
-- are the leavings of every blooding the order ever performed under this roof. That is the test the old
-- Lust failed and this has to pass -- a body on this stratum must be something the KEEP made, not
-- something that wandered in from another circle's ground.
--
-- THE CIRCLE'S FIFTH VERB, FIELDED BY SOMETHING A FLOOR CAN ROLL. models/descent.lua's Lust entry lists
-- five things this stratum does and glosses the fire one as "...and wanting costs, whether or not you
-- get there." Until this body that sentence was prose: the only fire on the ground rode the harpy's
-- talons, which is fire arriving the ordinary way. Nothing charged a company for REACHING
-- ([[prose-can-be-the-only-implementation]] is the shape, and it is the second time this circle has
-- been caught by it -- Charm was in exactly the same position before the succubus line).
--
-- SO IT IS THE OPPOSITE OF EVERY OTHER BURN IN THE GAME. A cinder-kin burns what it hits and Wrath's
-- whole stratum burns the ground you must stand on. This burns what reaches for IT -- the arrow as
-- readily as the axe, the spell as readily as the arrow (data/traits/trait_wanting_costs.lua) -- so
-- there is no distance at which answering it is free.
--
-- AND IT LEAVES THE GROUND BEHIND IT ALIGHT (data/items/utility/utility_living_flame.lua). A trail is
-- laid on the tile VACATED, never the one stood on (Combat.layTrail), so the thing needs no immunity of
-- its own and is never standing in its own print. In the Thinwall Keep that is the second half of the
-- body: it walks three tiles and a corridor is closed behind it, and a company that let one drift
-- across the room it meant to retreat through has lost the retreat rather than any health. The fire is
-- UNSIDED, exactly as the Cinderstride Boots' is -- it burns whoever walks into it, and on the player's
-- side of a summon that makes where the thing walks a real decision rather than a free one.
--
-- AND IT IS THE FIRST BODY ON THIS GROUND THAT DOES NOT CARE WHERE YOU ARE. Every other rule in the
-- circle is about position: the flock decides where your body is, the coils decide it does not get to
-- be anywhere else, the kiss takes your tile and gives you its own. The retaliation has no opinion
-- about the board at all -- it is a cost attached to an intention. A company that has learned to answer
-- this stratum by choosing its ground walks into the one thing on the floor that ground cannot answer.
--
-- `defensive`, AND THAT IS HALF THE FIGHT IT MAKES. It holds where it stands until the fight comes to
-- it (AI.POSTURES) -- a standing flame does not chase anybody, and one that walked at the party would
-- be a bad aggressor rather than a good obstacle. What that buys is the decision a lamp room is made
-- of: it can be opened when the company chooses, walked past, or left burning behind the line. (The
-- posture is read by the AI only, so a summoner's own elemental is unaffected -- it goes where it is
-- told, and the trail goes with it.)
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Twenty-two, unchanged from the conjuration it
-- also is, and the number does real work here. A reflex is held while a cast resolves and the flush
-- skips the fallen (Combat.endAnswers), so one KILLED by the blow that reached it bills nobody -- the
-- single free answer, and the only one. Twenty-two is what puts that inside a committed swing and
-- outside a careful one: go through a lamp room fast and it costs nothing, chip at it and every
-- exchange is another burn. The lesson is to be quick, on a stratum that has spent two floors teaching
-- patience.
return {
    name = "Fire Elemental",
    race = "elemental",
    tier = 1,
    sprite = "assets/chars/fire_elemental.png",
    -- THE CONJURATION'S OWN STAT LINE, CARRIED ACROSS UNTOUCHED. Frail and slow, hitting hard through
    -- magicDefense and shrugging off spells -- which is what an Arcanum summoner is buying and has been
    -- since the ability shipped (tests/summon_spec.lua pins the 22 outright: base 22 + the ability's
    -- amount). Nothing about the summon shelf's arithmetic moves because this body found a home; what
    -- moved is that it now has rules, and they are the two below the stats.
    stats = {
        health = 22, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 4, magicDamage = 14,
        defense = 2, magicDefense = 10,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 6,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Cutting a flame divides it into two flames. This has been tried.
    --   Smothering it works, and so does the whole of the Arcanum's cold shelf.
    resist = { fire = 2, slash = 2, impact = -2, water = -4, ice = -4 },
    startingItems = { "weapon_flame_fists", "utility_living_flame" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md). The bill, handed over: whoever damages the bearer catches
    -- fire. The rift sells you the trick, which is the ordering the Barrow Lord argues -- a rule like
    -- that is strange handed cold at a counter and ordinary handed by the corpse of the thing that
    -- spent a fight doing it to you.
    drops = {
        "utility_the_answered_wish",
    },
    defaultAction = "weapon_flame_fists",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
