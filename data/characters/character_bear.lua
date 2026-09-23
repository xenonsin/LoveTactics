-- THE BEAR: the road animal that teaches Fury Swipes, and the cub in character_sow.lua's fight.
--
-- IT IS NOT character_dire_bear, AND THAT IS THE POINT OF THE FILE. The Dire Bear is a SHAPE a hunter
-- wears (data/items/ability/ability_wild_shape_bear.lua): its pools are placeholders the hunter's own
-- body carries across, so its blueprint reads `health = 1` and `tier = 0`. Fielded as a combatant it
-- spawns with one health at level 1 and swings like a general -- which is not a hypothetical, it is the
-- bug the Gralloch was authored to replace, argued in models/descent.lua. A blueprint used as both cargo
-- and combatant has to be SPLIT. The druid's bear stays hers; this is the one anybody fights. (The
-- Gralloch itself is deleted -- all seven lieutenants came out on 2026-09-22 to be re-authored, and the
-- head of Descent.SINS carries that note; the split is the part that mattered and it stands.)
--
-- WHAT IT IS FOR, in two jobs that are the same job. On the road it is the body that teaches the one
-- compounding threat in the game -- meet it at ordinary size, watch the wound deepen, learn to break off
-- -- and in the sow's fight it is her cub, carrying the identical rule at the identical size. That is
-- the lieutenant tier's own pattern, which the Gralloch's header stated for all seven: the small body
-- teaches the rule the cheap way, and the big one has it in full. It also closes a real hole -- the bear shape is a
-- DRUID ability, so a party without one would otherwise meet Fury Swipes for the first time on a boss.
--
-- THE HIDE IS THE PUZZLE, AND IT POINTS AT ITS OWN WOUND. `pierce +3 / slash -3`: a point sinks into a
-- great depth of animal and finds nothing quickly; an edge finds a great deal of surface at once. Both
-- wolves and the boar are slash+/impact-, so this is the third axis rather than a heavier boar. And it
-- rhymes with the rule the animal carries -- Fury Swipes opens a SLASH wound, so the bear is fastest
-- killed along the same axis it kills you on, and the fight is one race rather than two puzzles.
--
-- ...AND THE ARMOUR IS THE `defense` STAT, WHICH IS WHERE "TOUGH ALL OVER" BELONGS. 9 is the highest of
-- any beast on the road (the boar runs 7, the alpha wolf 6) and says the thing a blanket `physical`
-- resist would have said -- except that `physical` subtracts from all three melee probes at once, which
-- is precisely what this number already is. Naming it in `resist` is refused by tests/bestiary_spec.lua
-- for exactly that reason, and the three physical lines must sum to zero besides.
--
-- ARMOURED AND DANGEROUS, NOT SPONGY -- and that distinction was MEASURED rather than chosen. The first
-- cut ran 62 health behind defense 11 and the road fight came out at 26 unit-turns against
-- tests/skirmish_spec.lua's budget of 22: an ordinary stop had grown back into a set-piece. The cause is
-- the defense and not the health, because mitigation here is SUBTRACTIVE -- every point comes off every
-- blow the party throws, so a high guard on a body that also has to be chewed through is a grind twice
-- over. The hide came down two, and it stays down.
--
-- THE SAME PASS ANSWERED THE OPPOSITE FAILURE, which is why the numbers are read together rather than
-- one at a time. tests/descent_spec.lua rated the floor-5 fight at 218% of the company -- past
-- Muster.WALK_OVER, meaning it could be skipped without being fought -- so the body had to get CHEAPER
-- to kill without getting cheaper to RATE. Muster prices offense at 4x health (Muster.STAT_WEIGHTS),
-- which is the whole lever: health and damage trade against each other four to one at a fixed rating,
-- and where a body sits on that line decides what a fight costs without touching what it is worth.
--
-- 46 AND 19 IS WHERE IT LANDED, and the alternative was measured rather than reasoned away. THE PARTY
-- DOES NOT HEAL BETWEEN FIGHTS, so a road stop is also priced in what the company no longer has for the
-- next one -- which argued for trading damage back into health (58 and 16, the identical 146 of muster,
-- the same body further along the same line). Measured, that made the bear's OWN fight longer than the
-- budget it was trying to protect: 24 unit-turns against 22, where 46 and 19 runs 20. More health is
-- more fight, and a bear that takes a third longer to put down spends the company through the clock
-- instead of through the claws. The lighter, harder-hitting body is the cheaper stop of the two.
--
-- The count carries the rest; see data/encounters/encounter_bear.lua.
--
-- Tier 2's band is 31-80 health. It is still the hardest ordinary animal on the road -- it is the one
-- whose threat grows if you stand there -- but what makes it hard is now the ramp rather than the wall.
--
-- No `drops` yet. The boar's list was authored against a measured placement pass (docs/drops.md,
-- `. drop-report`), and guessing one here would put two items on a shelf nothing has priced.
return {
    name = "Bear",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/bear.png",
    stats = {
        -- The 24 pool is the rate limiter on the ramp, the way the boar's 10 is the limiter on its
        -- charge. Great Claws costs 12 and this regains 3 a tick, so a bear gets a swipe, then has to
        -- stand there and earn the next one -- which is the window the party breaks the chain in. Raising
        -- this is raising how fast the only compounding threat in the game compounds; measure it through
        -- models/autobattle.lua before touching it, as ability_gore's header records doing.
        health = 46, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 19, magicDamage = 0,
        defense = 9, magicDefense = 3, -- armoured all over (see the header); nothing at all about magic
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        --
        -- Skill 3 is load-bearing rather than flavour: Fury Swipes only counts blows that LAND
        -- (trait_fury_swipes gates on damage dealt), so a bear that misses has broken its own chain. An
        -- evasive party is a real answer to the ramp, and that answer only exists because this number is
        -- ordinary.
        skill = 3, luck = 4,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Depth. A point goes in and is still going in, and finds nothing that matters.
    --   And a great deal of loose hide over all of it, which an edge opens the length of.
    resist = { pierce = 3, slash = -3 },
    -- NO FERAL INSTINCT, AND THAT IS THE ANIMAL'S IDENTITY BEING PROTECTED. The boar and both wolves
    -- carry it because a cornered pack animal whipping back IS what they are; a bear's rule is the
    -- ramp, and a third mechanic on this sheet would make the road bear a boar that also compounds.
    --
    -- It also costs the company far more than it looks. THE PARTY DOES NOT HEAL BETWEEN FIGHTS, so a
    -- road stop is priced in what the company no longer has for the next one -- and a counter on every
    -- body in a four-strong group is four free blows a round, taken by whoever was doing the killing.
    -- tests/skirmish_spec.lua measures that sequence rather than one fight, and this showed up there as
    -- the BOAR fight growing by a turn: the company was arriving at it already spent. Muster reads
    -- stats and not traits (Muster.STAT_WEIGHTS), so dropping this costs the fight nothing in RATING
    -- and a great deal in attrition -- which is the right trade in both directions at once.
    startingItems = { "weapon_great_claws", "utility_the_same_wound" },
    defaultAction = "weapon_great_claws",
    archetype = "aggressive",
    -- Basic tactics (models/ai.lua). Deliberately the roster's ordinary rule and NOT a bespoke one that
    -- chases stacks: the planner prices stamina and steps and cannot see that a fourth blow is worth
    -- triple the first, so a rule written to exploit the ramp would be a rule the scorer cannot honour.
    -- Pressing whatever is closest to falling keeps it on one body often enough for the wound to deepen
    -- on its own, which is the ramp arriving out of ordinary behaviour rather than out of an exception.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
