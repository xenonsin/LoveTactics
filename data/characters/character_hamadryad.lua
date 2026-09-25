-- THE HAMADRYAD: the top of the Dryad line, and the Lust circle's MOVE elite.
--
-- A HAMADRYAD IS THE DRYAD WHOSE LIFE IS IN ONE TREE, and dies when it does. This one walks onto the
-- board with it (trait_heartwood plants her Heartwood Tree beside her at the bell), and while it stands
-- no blow kills her -- a killing blow leaves her at 1 and sets her down beside it
-- (data/status/status_heartbound.lua). THE CIRCLE'S STANDING LAW, TWISTED: cut the one doing it, and the
-- one doing it is not her. It is a tree, which is an object, open to an axe and to fire.
--
-- SHE KEEPS THE DRYAD'S GROVE and adds the two spells that move a company without shoving it:
--
--   Through the Grain  a foe standing beside a plant is put out beside a different one, wherever
--                      strands it farthest from its friends (weapon_through_the_grain) -- the answer to a
--                      company that planted itself in open ground.
--   Wild Growth        every thorn patch and hedge of hers grows a tile (weapon_wild_growth).
--
-- NOT A BOSS (docs/bestiary.md: `boss = true` means an assassinate mark and nothing else). Charmable,
-- Polymorphable and open to a finisher, as every elite on this stratum is -- and a finisher on her
-- while her tree stands is a finisher that leaves her at 1.
--
-- Tier 3's band is 81-154 health (Balance.HEALTH_BANDS). Lower in it than the stratum's other elites: a
-- body that cannot die while its tree stands does not also need the bar.
return {
    name = "Hamadryad",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/hamadryad.png",
    archetype = "skirmish",
    stats = {
        health = 90, mana = 72, stamina = 16,
        staminaRegen = 2,
        damage = 10, magicDamage = 15,
        defense = 8, magicDefense = 12,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 9, luck = 8,
    },
    resist = { slash = 4, impact = -4, fire = -6, holy = -4 },
    startingItems = { "weapon_through_the_grain", "weapon_thorn_whip", "weapon_briarfloor",
                      "weapon_quickset", "weapon_wild_growth", "weapon_barkskin",
                      "weapon_mistlight", "weapon_greenstep", "utility_heartwood_bond" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), rarest first: her bond, carried at a fraction of its
    -- strength; the bow cut from her tree; her spell; and the Dryad's thorns, so a company that holds the
    -- rest is paid rather than refused.
    drops = {
        "utility_heartwood",
        "weapon_churchyard_yew",
        "ability_through_the_grain",
        "ability_briarfloor",
        -- Ground that heals, off the grove's heart (moved off Luxuria's list, 2026-09-25).
        "weapon_renewal_staff",
    },
    defaultAction = "weapon_thorn_whip",
    ai = {
        { priority = "high", act = "attack", item = "weapon_through_the_grain", targetPref = "nearest",
          when = { subject = "any_foe", test = "within", value = 5 } },
        { priority = "normal", act = "attack", item = "weapon_briarfloor", targetPref = "nearest",
          when = { subject = "any_foe", test = "within", value = 4 } },
    },
}
