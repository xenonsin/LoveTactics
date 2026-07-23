-- Cathedral rank-3. Every heal the wearer casts also lays a Physical Barrier on its target
-- (trait_guardians_blessing) -- one blow, negated outright.
--
-- THE BEST MULTIPLIER ON THE SHELF, because it costs no action of its own. A barrier NEGATES rather
-- than reduces (Status.barrierAgainst), so a Heal cast through this chasuble is worth its own number
-- plus whatever the next axe was going to be, and the priest was going to cast the Heal anyway.
--
-- What holds it down is that it does nothing on its own: an armour that only speaks when its wearer
-- casts is dead weight in a grid without heals, and the ward refreshes rather than stacks (Status.apply)
-- so healing one ally twice in a beat does not give them two barriers. It rewards spreading the mending
-- around, which is the behaviour the Cathedral wanted out of its healers in the first place.
--
-- Read against armor_shared_bulwark, which hands the same ward to a whole line at once but only while
-- they stand on its ground. This one goes wherever the priest can reach and asks for a cast instead of
-- a formation -- the same ward bought with the two different currencies the game has.
--
-- Cloth: a square of pace, which a caster at range can afford better than anyone.
return {
    name = "Warding Chasuble",
    description = "Your heals also lay a Physical Barrier on their target: one blow, negated.",
    flavor = "The Cathedral vests its field healers in it and its cloistered ones in nothing at all.",
    sprite = "assets/items/armor_warding_chasuble.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    price = 420,
    repRank = 3,
    traits = { "trait_guardians_blessing" },
    bonus = { magicDefense = { 5, 6, 6, 7, 7, 8, 9, 9, 10, 10, 11 }, defense = { 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5 }, movement = -1 },
    resist = { magical = { 2, 2, 3, 3, 3, 4, 4, 4, 4, 5, 5 } },
}
