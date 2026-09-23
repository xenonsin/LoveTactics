-- A SWOONCAP VERGER: the mushroom folk's brute, and the one that makes you hit it.
--
-- A VERGER WALKS AT THE HEAD OF A PROCESSION WITH A STAFF AND KEEPS ORDER IN THE NAVE. This one bangs
-- its staff on the flags and every foe within two tiles has to deal with it first (weapon_call_to_order,
-- status_taunt), and every melee blow it survives puffs Swoon back into the striker's face
-- (trait_spongeflesh). So the front of the mushroom folk is a body the company is compelled to hit with
-- the one kind of blow that takes its hitters out of the fight.
--
-- THE ANSWER IS MAGIC OR REACH, AND THE LAW OF THE CIRCLE. The flesh only answers a melee hand; the taunt
-- ends when the taunter falls. A mage at range kills it without ever being asked, and a company that
-- walks round it to the Thurifer behind it has done the right thing in the right order.
--
-- PHYSICAL, AND IT BURNS: the cap-staff is a demon's blow (docs/bestiary.md), so a coat still answers it.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS). High in it: holding the front is the job.
return {
    name = "Swooncap Verger",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/swooncap_verger.png",
    archetype = "aggressive",
    stats = {
        health = 76, mana = 0, stamina = 26,
        staminaRegen = 3,
        damage = 12, magicDamage = 0,
        defense = 9, magicDefense = 4,
        movement = 3,
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 3,
    },
    -- INNATE MITIGATION (docs/bestiary.md). A maul sinks into it and comes out damp; an edge cuts it
    -- like bread. Poison is the air it breathes, and the blood in the pit is Luxuria's.
    resist = { impact = 3, slash = -3, poison = 3, holy = -3 },
    startingItems = { "weapon_cap_staff", "weapon_call_to_order", "utility_spongeflesh" },
    drops = {
        "armor_spongeflesh_mantle",
        "consumable_puffball",
    },
    defaultAction = "weapon_cap_staff",
    ai = {
        { priority = "high", act = "cast", item = "weapon_call_to_order",
          when = { subject = "any_foe", test = "within", value = 2 } },
        { priority = "normal", act = "attack", item = "weapon_cap_staff", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
