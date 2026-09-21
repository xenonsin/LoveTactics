-- THE WILD BOAR: the enemy that asks which LINE you are standing on.
--
-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
--
-- It is the commonest animal in the game -- encounter_boar at weight 6 from day one, three at a time in
-- encounter_the_sounder, and the Lodge's first commission scales them by the day -- and for a long time
-- it was the one with the least to say. It carried the wolves' `weapon_fangs` and the Ancient Stag's
-- exact AI rule under a different comment, which made the two animals one unit with different numbers.
--
-- Its own resist line was already saying what it is, and nothing else in the file was listening:
-- bristle over fat, turns a blade, folds to a mace. **It is armour that runs at you in a straight
-- line.** ability_gore is that sentence made into a turn, and weapon_tusks is what it has instead of
-- somebody else's teeth. See docs/bestiary.md on why a shared blueprint splits rather than lies.
return {
    name = "Wild Boar",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/boar.png",
    stats = {
        -- THE 10 POOL IS THE RATE LIMITER ON GORE, and it is load-bearing rather than incidental. A
        -- charge costs the whole bar at 1 stamina a tick, which is what makes it an opener and what
        -- keeps the ordinary road fight inside tests/skirmish_spec.lua's budget. Raising this to 14
        -- with 2 regen -- to stop a boar in a LONG fight idling after its charge -- was measured and
        -- reverted the same hour: the road fight went from 19 unit-turns to 44, because every point
        -- of stamina is another telegraphed charge and the charge is tempo-negative by construction
        -- (see ability_gore.lua's own note). The idling is real; the fix is not here.
        health = 50, mana = 0, stamina = 10,
        damage = 14, magicDamage = 0,
        defense = 7, magicDefense = 1,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Bristle over a hand's depth of fat, which is what a boar is for.
    --   The fat is not structural. A mace does not care what it is wrapped in.
    resist = { slash = 3, impact = -3 },
    startingItems = { "weapon_tusks", "ability_gore", "utility_feral_instinct" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md). Neither of these is a body part -- that rule is absolute and
    -- the tusks and the instinct are on the far side of it, unstealable and on no shelf. These are the
    -- two things a boar is actually carrying: its hide, and the spear somebody left in it.
    --
    -- The first `drops` list on a beast in the game. Nineteen beasts are placed and none had one, so
    -- every drop they have ever paid came through the band -- which is the route for the TAIL of the
    -- catalogue, not the route for the commonest animal on the road. Spoils reads `def.drops` with no
    -- kind gate; what the bestiary forbids is a creature's own KIT entering the pool, which this is not.
    drops = { "armor_bristlehide", "weapon_unclosing_spear" },
    -- What it does on the turns it could not line anybody up. Named so the fallback is the jab rather
    -- than whatever the grid happens to list first, since the charge is now also in there.
    defaultAction = "weapon_tusks",
    -- Basic tactics (models/ai.lua). The charge carries its own rule (ability_gore's `ai`), and that
    -- rule is reached FIRST -- an item's rule sits above the body's in AI.rulesFor -- so the order here
    -- reads: line somebody up if you can, and otherwise go for the throat that is already open.
    --
    -- Nothing below restates the geometry. Whether a charge is available at all is answered by the
    -- ability's own footprint catching somebody, which is a fact about where everyone is standing and
    -- cannot be said again here without the two copies drifting.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
