-- The Demon Lord, and the end of everything the seven ladders were counting toward. Enemy blueprint;
-- the objective of data/quests/quest_the_gate_below.lua. See docs/story.md.
--
-- It has no sin. The seven were its appetites, and you have spent the whole game taking them off it
-- one at a time -- which is why its `traits` are the only thing it brings: as it fails, it puts the
-- dead generals back on (data/traits/hollow_crown.lua).
--
-- Its own stats are those of something that has not had to fight in a very long while: an enormous
-- pool of health and almost nothing behind it. Every threat in this battle is borrowed.
return {
    name = "The Hollow Crown",
    kind = "demon",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. This body is authored as the fight it is at the end
    -- of its line, and models/growth.lua scales it DOWN toward the shallows rather than growing it up
    -- from a base -- so a descent that deals this circle as floor 1 meets a smaller version of the
    -- same thing instead of an unkillable one. At this level the numbers below are exactly the
    -- numbers. See Growth.spawn.
    referenceLevel = 13,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/demon_lord.png",
    revivable = false, -- a demon does not come back: no downed window, and no revive takes it
    stats = {
        health = 462, mana = 0, stamina = 25,
        damage = 20, magicDamage = 20,
        defense = 5, magicDefense = 14,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Grown plate over the whole of it, and there is no edge in the game that opens it.
    --   Weight opens it. Its holy line lives on the crown, not on the body (utility_demonic_essence).
    resist = { slash = 5, impact = -5 },
    -- Its loadout as the 3x3 grid (row-major); false = an empty cell. Its rule rides on the Hollow Crown
    -- relic in the center (data/items/armor/armor_hollow_crown.lua): a bound item -- here `bound`
    -- matters because a party rogue can never pickpocket it, so the boss can't be stripped of its entire
    -- fight. No weapon of its own (`unarmed` is what's left when everything borrowed is stripped away);
    -- its one carried thing isn't gear but demonic flesh, which takes holy damage the harder (a negative
    -- holy resist folded in as passive armor). Demon Bane was forged for exactly this body.
    startingItems = {
        false, false,              false,
        false, "armor_hollow_crown", "utility_demonic_essence",
        false, false,              false,
    },
    -- Basic tactics (models/ai.lua): the crown hunts the failing -- press the foe closest to falling
    -- with whichever dead general's threat it is wearing this turn.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
