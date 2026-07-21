-- The Demon Lord, and the end of everything the seven ladders were counting toward. Enemy blueprint;
-- the objective of data/quests/the_gate_below.lua. See docs/story.md.
--
-- It has no sin. The seven were its appetites, and you have spent the whole game taking them off it
-- one at a time -- which is why its `traits` are the only thing it brings: as it fails, it puts the
-- dead generals back on (data/traits/hollow_crown.lua).
--
-- Its own stats are those of something that has not had to fight in a very long while: an enormous
-- pool of health and almost nothing behind it. Every threat in this battle is borrowed.
return {
    name = "The Hollow Crown",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/demon_lord.png",
    stats = {
        health = 420, mana = 0, stamina = 100,
        damage = 20, magicDamage = 20,
        defense = 14, magicDefense = 14,
        movement = 3,
        speed = 3,
    },
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
}
