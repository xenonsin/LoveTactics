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
    sprite = "assets/chars/demon_lord.png",
    stats = {
        health = 600, mana = 0, stamina = 100,
        damage = 20, magicDamage = 20,
        defense = 14, magicDefense = 14,
        movement = 3,
        speed = 3,
    },
    traits = { "hollow_crown" },
    -- No weapon of its own. `unarmed` is what is left when everything borrowed has been stripped away.
}
