-- THE DREAD OF THE WHITEOUT: the yeti matriarch, an elite on the tundra's approach ("Sloth's Bestiary", slice A,
-- 2026-10-04). She walks with two or three yeti, and they do her rooting.
--
--   WHITEOUT              she is Unseen to foes more than 2 tiles away (utility_the_whiteout, trait_whiteout --
--                         the Shadow Mantle's `concealedBeyond`, at 2)
--   DRAG INTO THE WHITE   at the top of her turn she hauls the nearest Rooted foe 3 tiles toward her and away from
--                         its friends, still Rooted (utility_drag_into_the_white, trait_drag_into_the_white)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: close the distance as a group so she cannot pick anyone off.
-- Limn her, or keep a body near enough to see her.
--
-- She does not roar; her yeti do. Kill them and nothing on the board is Rooted for her to take.
return {
    name = "The Dread of the Whiteout",
    race = "beast",
    tier = 3,
    sprite = "assets/chars/dread_of_the_whiteout.png",
    stats = {
        health = 104, mana = 0, stamina = 32,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 6, luck = 4,
    },
    resist = { impact = 3, pierce = -3 },
    startingItems = {
        "weapon_yeti_claws", "utility_the_whiteout", "utility_drag_into_the_white",
        false,               false,                  false,
        false,               false,                  false,
    },
    drops = { "armor_whiteout_cloak" },
    defaultAction = "weapon_yeti_claws",
    archetype = "aggressive",
}
