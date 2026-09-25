-- A SWOONCAP THURIFER: the mushroom folk's mage, and the one to kill first.
--
-- A THURIFER CARRIES THE CENSER IN A PROCESSION. This one swings its own cap, and the spores come off it
-- like smoke: a cloud that walks with it and Swoons every foe beside it (weapon_thurifer_cap, laid by
-- Combat.layIncense exactly as the Cathedral's censers carry theirs). From behind the Verger it casts:
--
--   Spore Bolt      magic damage at range, and Poison (weapon_spore_bolt).
--   Sporebloom      it sets off its own Puffer that has the most foes beside it, wherever it stands
--                   (weapon_sporebloom) -- every Puffer on the board is a mine it can pull.
--   Mycelial Heal   every mushroom of its side within three tiles is healed (weapon_mycelial_heal) --
--                   what keeps the Verger standing long enough to matter.
--
-- SO THE ORDER IS THE FIGHT. Kill it and the Puffers must walk to you and the Verger is not mended; leave
-- it and the whole party is one body.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS). Low in it: the caster at the back.
return {
    name = "Swooncap Thurifer",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/swooncap_thurifer.png",
    archetype = "skirmish",
    stats = {
        health = 44, mana = 50, stamina = 12,
        staminaRegen = 2,
        damage = 6, magicDamage = 12,
        defense = 4, magicDefense = 9,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 5,
    },
    resist = { impact = 3, slash = -3, poison = 3, holy = -3 },
    startingItems = { "weapon_spore_bolt", "weapon_sporebloom", "weapon_mycelial_heal", "weapon_thurifer_cap" },
    drops = {
        "weapon_spore_censer",
        "consumable_puffball",
        -- A thurifer carries a censer; two of the priest finds that waited on Luxuria's list (2026-09-25).
        "weapon_censer_of_the_hollow_dark", "weapon_censer_of_the_unravelling",
    },
    defaultAction = "weapon_spore_bolt",
    ai = {
        { priority = "urgent", act = "cast", item = "weapon_mycelial_heal",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        { priority = "normal", act = "attack", item = "weapon_spore_bolt", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "within", value = 4 } },
    },
}
