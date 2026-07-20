-- Quest reward, slot 8 of the Bastion's line (data/quests/what_the_bastion_knows.lua): the page out
-- of the order's own record, with the terms on it and the seal that signed them. Not a weapon, not a
-- trophy -- the fact.
--
-- It carries Rowan's third oath (data/traits/trait_oathward_declared.lua), and that is the arc paying
-- out. Oath two, the innate Oathward on her Sworn Aegis, takes the first blow each turn for whoever
-- is standing beside her -- an unlimited promise that never chooses. Oath three names ONE ally and
-- guards them absolutely. What lets her make the narrower promise is learning what the wide one was
-- worth: she swore on Acedia's name, every knight does, and the name was a lie the order kept because
-- it was cheaper than the truth. An oath owed to an order or an icon is worth what this page is
-- worth. One owed to the person in front of you is not.
--
-- Given at slot 8 rather than after the general, deliberately: the player needs the declared guard in
-- hand for slots 9 and 10, or the whole arc resolves in dialogue instead of on the board.
--
-- `class = "knight"` with no `price`: unbuyable, still tallying toward knight growth (docs/classes.md).
--
-- KNOWN DEBT: the design says this should re-swear the Sworn Aegis itself -- an in-place trait swap on
-- a `bound` item (data/items/armor/armor_sworn_aegis.lua), which can never be replaced by a better
-- shield because being unreplaceable is the point of it. There is no mechanism for that swap yet, so
-- the new oath arrives as a second grid item instead. It works, and it is a shade less pointed than
-- the shield she swore on changing what it means.
return {
    name = "The Struck Name",
    description = "Names one ally at the start of battle. Every blow on them is taken by you instead.",
    flavor = "A page from the muster record, and a seal at the foot of it. The order read her name " ..
        "aloud for fifteen years off the front of every shield it sold.",
    sprite = "assets/items/struck_name.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    traits = { "trait_oathward_declared" },
}
