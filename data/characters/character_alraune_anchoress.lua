-- THE ALRAUNE ANCHORESS: the top of the Alraune line, and the Lust circle's HOLD elite.
--
-- AN ANCHORESS IS A WOMAN WALLED INTO A CHURCH, and she keeps the hours of prayer from her cell. This one
-- is walled into the keep's floor. She cannot be moved (trait_nothing_to_hold) and she does not walk
-- (`movement = 0`): the fight is the company going to her, through her garden.
--
-- THE ESCALATION IS IN KIND. She keeps every spell the Alraune casts, and adds two things:
--
--   Compline       every Mandrake of hers screams at once and none of them dies (weapon_compline) --
--                  telegraphed a turn ahead, so the company has one turn to get out of their reach,
--                  cut them down (each one it cuts screams on its own), or break her channel.
--   The Pit Grows  any death within three tiles sprouts a new Mandrake where the body fell
--                  (trait_the_pit_grows) -- so every body she drops plants the next one.
--
-- So the fight is not "can you kill her". It is "where does your company die", because every place it
-- dies becomes a thing that roots and screams. Cut her and the garden goes back into the floor with her
-- -- a sprout is her summon, and a dismissal does not scream.
--
-- NOT A BOSS (docs/bestiary.md: `boss = true` means an assassinate mark and nothing else). She is the
-- discipline stated, and so she is Charmable, Polymorphable and open to a finisher, as every elite on
-- this stratum is.
--
-- Tier 3's band is 81-154 health (Balance.HEALTH_BANDS).
return {
    name = "Alraune Anchoress",
    race = "demon",
    tier = 3,
    plant = true,
    sprite = "assets/chars/alraune_anchoress.png",
    archetype = "guard",
    stats = {
        health = 104, mana = 72, stamina = 10,
        staminaRegen = 2,
        damage = 6, magicDamage = 16,
        defense = 7, magicDefense = 13,
        movement = 0, -- walled in
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 9, luck = 8,
    },
    resist = { pierce = 4, slash = -4, dark = 4, fire = -6, holy = -4 },
    -- THE GARDEN'S OWN GROUND: sweetbriar, which Charms whoever blunders into it. It was the forest's
    -- signature hazard while the wood was Lust's; the wood went to Gluttony (and its web), and the briar
    -- came with the circle it was written for -- laid by the bodies that grow it (models/arena.lua).
    seedsGround = { id = "hazard_sweetbriar", count = 3 },
    startingItems = { "weapon_nightshade", "weapon_honeyed_ground", "weapon_gallows_seed",
                      "weapon_taproot", "weapon_compline", "utility_the_anchorhold",
                      "utility_mandrake_scream" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), rarest first: her rule, narrowed to a company's kills; then
    -- the Alraune's two, so a company that already holds the first is paid rather than refused.
    drops = {
        "utility_the_pit_grows",
        "ability_gallows_seed",
        "consumable_mandragora",
        -- The censer that roots, off the body that holds (moved off Luxuria's list, 2026-09-25).
        "weapon_censer_of_the_grasping_hollow",
    },
    defaultAction = "weapon_nightshade",
    ai = {
        { priority = "urgent", act = "attack", item = "weapon_nightshade", targetPref = "nearest",
          when = { subject = "any_foe", test = "has_status", value = "status_sleep" } },
        { priority = "high", act = "attack", item = "weapon_honeyed_ground", targetPref = "nearest",
          when = { subject = "any_foe", test = "lacks_status", value = "status_honeyed" } },
        { priority = "normal", act = "attack", item = "weapon_gallows_seed", targetPref = "nearest",
          when = { subject = "any_foe", test = "lacks_status", value = "status_gallows_seed" } },
    },
}
