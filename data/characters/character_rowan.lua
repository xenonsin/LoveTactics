-- Rowan, the knight companion (diligence) and the player's FIRST recruit -- she rallies to defend
-- the burning village, fights at your shoulder, and when it is ash she swears her broken oath anew
-- to you (states/prologue.lua). She is the foil to sloth, whose general is the oath abandoned; Rowan
-- is the oath kept. The oath makes her the player's bodyguard and mentor: she guards the body she
-- swore to and teaches the trade she already knows, so hers is the voice that warns and explains and
-- the body that steps in front. See docs/story.md, "The other seven": a woman, a gender-neutral name,
-- the virtue shown in how she fights (the wall that holds its post), never labeled.
--
-- Her blueprint id is `character_rowan`. It used to be `character_knight`, but that name was freed to
-- hold the *generic* knight template (the relic-less base every knight companion specializes from);
-- Rowan is a named companion and now carries a proper id like the other six. See
-- data/characters/character_knight.lua for the generic she is built on.
return {
    name = "Rowan",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/rowan.png",
    portrait = "assets/portraits/knight.png", -- large VN portrait for conversations (falls back if missing)
    -- Innate growth class: the fallback (and tie-break) for the level-up growth system when this
    -- character has no cast history yet. See models/growth.lua and data/growth/<class>.lua.
    class = "knight",
    -- The wall, like every knight (see character_knight.lua): it holds a post rather than hunting a
    -- kill, fights whatever comes to that post, and refuses to be baited off it (models/ai.lua's
    -- `defensive` posture).
    archetype = "defensive",
    -- ...but the post is not the map's to name. Every other defender reads its post off the objective
    -- -- the boss on an assassination, the node on a control map -- and Rowan does not, because her
    -- assignment predates the arena: she swore herself to the player in the ashes of the village and
    -- has stood in front of that body ever since. So she takes the post the SIDE needs held, on every
    -- map, whatever the objective says (models/ai.lua's AI.postedUnit reads this ahead of
    -- `combat.objective`; AI.CHARGE_WEIGHTS is the ranking).
    --
    -- Not a hard-coded "character_avatar", though that is what it resolves to in most fights the
    -- player is standing in -- the avatar outranks every other term put together, because losing that
    -- body ends the run. Naming the ranking instead of the id is what makes the oath survive the
    -- fights the avatar is NOT in: dropped into a defence where the party escorts a witness, or a
    -- battle carried by the healer, she stands in front of whoever cannot stand for themselves rather
    -- than holding a post nobody is at. Which is the same oath, kept by a knight who can read a
    -- battlefield -- and it means the player never has to station her: she rings her charge at
    -- AI.POST_RADIUS, engages the moment anything contests that ring, and does not chase the wounded
    -- straggler across the board to leave the body she is guarding open.
    --
    -- The one body that takes her off the player is an objective's `protect` clause -- the caravan on
    -- the road to Highwatch, the witness on a defence. That is not the map outranking the oath; it is
    -- the oath read properly. Both deaths end the fight, and of the two the player is the one with a
    -- hand on the reins. She stands in front of the thing that cannot move itself out of the way, and
    -- trusts you to. (AI.CHARGE_WEIGHTS.PROTECT.)
    --
    -- On a side of nothing but hitters the ranking names nobody, and she is a plain defender holding
    -- until the fight reaches her.
    guards = "priority",
    stats = {
        health = 70, mana = 15, stamina = 15, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 14, magicDamage = 4,          -- flat stats
        defense = 3, magicDefense = 6,
        movement = 4, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
    },
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. The
    -- build-around is the Sworn Aegis relic in the center (data/items/armor/armor_sworn_aegis.lua):
    -- a bound item -- never moved, stowed, sold, or stolen, only forged -- that carries the Knight's
    -- Oathward guard. Frontline steel around it: chainmail for all-round defense (only -1 movement so
    -- it keeps pace), a potion to self-heal under fire, and the party's torch (its overworld vision
    -- -- see Player.visionRadius).
    --
    -- The MACE rather than a sword, and it is characterisation rather than loadout trivia. A mace
    -- hits and then SHOVES, two tiles straight back (data/items/weapon/weapon_iron_mace.lua) -- it is
    -- the knight's shelf precisely because displacement is the wall's trade and not wrath's
    -- (docs/classes.md). Rowan does not kill you, she decides where you stand, and every fight she is
    -- in reads that way from the first swing. The prologue is built on it: she shoves the demon grunt
    -- off the player and opens the gap the Jolt is taught in (data/tutorials/village.lua).
    --
    -- She gives up Parry for it -- the sword's free answer to an adjacent blow. That is the trade the
    -- weapon families exist to make (docs/weapons.md), and it costs her nothing in the village fight,
    -- where the imps spit from two tiles away and there is no blow to answer.
    startingItems = {
        "weapon_iron_mace",  "armor_chainmail",   "consumable_healing_potion",
        "utility_torch",     "armor_sworn_aegis", false,
        false,        false,             false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "weapon_iron_mace",
    -- THE TWO ITEMS THAT ARE THIS UNIT, named for the same reason every hall hero names them: a base
    -- class is met on a floor like any other body now (models/descent_recruit.lua), and this is the
    -- pair its card is written from.
    signatureWeapon  = "weapon_iron_mace",
    signatureAbility = "armor_sworn_aegis",
    -- Basic tactics (models/ai.lua): the wall still knows a kill when it sees one -- under auto-battle
    -- she turns the mace on the foe already closest to falling, and shoves it where the shove helps.
    -- From the ground she is holding, though: the `defensive` posture leashes her stand tiles to the
    -- ring around the player, so this picks the best target among what has come to her.
    ai = {
        { act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
