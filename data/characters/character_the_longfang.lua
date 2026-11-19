-- THE LONGFANG: the pride's leader. Named rather than titled (round two: "Rename"; round three chose The
-- Longfang over Sabertooth Matriarch and Elder Sabertooth), the way the wyverns have The Highwing.
--
-- SHE WAS the Sabertooth plus one sentence -- "and a kill does not bring her out of hiding" (The Unbroken
-- Stalk, approved as option A of round three). The creature identity pass (2026-11-19, "same-pounce")
-- found the two cats one loop -- both pounced out of Invisible, both struck back -- and split them.
--
-- WHAT SHE IS NOW. She does not hide: no Tawny Hide. She stands in the open at the head of the pride,
-- strikes back when struck (Feral Instinct, which the Sabertooth gave up), and her rule is LENT: while she
-- stands, a cat within three tiles of her that downs a body from hiding stays hidden into its next turn
-- (The Longfang's Hunt, data/traits/trait_the_longfangs_hunt.lua). Her drop is still The Unbroken Stalk --
-- the same trick, worn by one person on themself.
--
-- SO THE PRIDE IS AN ORDER QUESTION. She is the one body always in sight, and killing her first makes her
-- cats ordinary ambushers again; leave her standing and every kill a cat makes is a cat you never see. The
-- cats' own answers still hold: keep everyone above one critical bite, and an area blast or Witchlight
-- reaches a hidden cat. She walks at whoever is nearest -- the front she is drawing.
--
-- HER HIDE ASKS FOR A BLADE, as her cats' does (same pass, "same-mace"): slash -3, impact +3.
return {
    name = "The Longfang",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/the_longfang.png",
    stats = {
        health = 60, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 18, magicDamage = 0,
        defense = 7, magicDefense = 3,
        movement = 4,
        speed = 5, -- first of the pride
        skill = 4, luck = 6,
    },
    resist = { slash = -3, impact = 3 },
    startingItems = {
        "weapon_pounce",          "utility_the_longfangs_hunt", "utility_wood_walker",
        "utility_feral_instinct", false,                        false,
        false,                    false,                        false,
    },
    drops = { "utility_the_unbroken_stalk" },
    defaultAction = "weapon_pounce",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
