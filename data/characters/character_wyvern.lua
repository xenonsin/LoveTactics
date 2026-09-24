-- THE WYVERN: Gluttony's seat-floor flier, and the one animal in the wood that survives by never fighting
-- anything its own size. Pitched and reviewed in two rounds (2026-09-23, "The Wyverns" artifact); round
-- one's appetite line -- swallow whole, gorged, first bite -- was thrown out for this one.
--
-- THE LOOP, as reviewed:
--   Wind Shear   a cut of wind at 2-3 tiles, slash AND wind, then it drifts a tile back. Never adjacent.
--   Tailwind     +25 Avoid while no foe is beside it -- the cover a flier gives up, in wind instead
--   Take Wing    everyone beside it blown back a tile, and it goes Aloft: out of every aim, every blow.
--                A wind-up, so it ALWAYS comes down (models/stoop.lua): beside the foe it marked, and if
--                that foe stands alone it is carried three tiles off and dropped -- a fall that kills at
--                or under twice the wyvern's Damage
--   Wings        the flier's trade, shared with the manticore
--
-- THE COUNTERPLAY, STATED, and it is the review's own: STAY TOGETHER (a body with a friend directly beside
-- it is not lifted, and the dive then does it no harm) and ROOT IT (a held wyvern cannot take wing, and a
-- held body cannot be carried). Beyond those: close the gap (the Shear cannot reach, the Tailwind drops),
-- Mark it (Mark cuts Luck, and Luck is Avoid -- the Lodge's whole aiming shelf), and hit it the turn after
-- it dives, when it is on the ground beside somebody.
--
-- NOT THE MANTICORE, which shares its stair. That one is easy to hit and comes in to bite; this one is
-- hard to hit and never commits except to take someone. The manticore is pierce -3; this is IMPACT -3 --
-- a bow answers one of the seat's fliers and a hammer the other.
return {
    name = "Wyvern",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/wyvern.png",
    stats = {
        health = 44, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 13, magicDamage = 0, -- it does not need to hit hard; it needs you alone
        defense = 4, magicDefense = 4, -- soft, once anything reaches it
        movement = 5, -- flying: every tile costs one (utility_manticore_wings)
        speed = 6,
        -- Accuracy (docs/accuracy.md): luck raises Avoid, and Avoid is how this body lives. Mark cuts it.
        skill = 5, luck = 7,
    },
    -- INNATE MITIGATION: scale turns an edge and its own element; weight brings it out of the air.
    resist = { slash = 3, impact = -3, wind = 3 },
    startingItems = {
        "weapon_wind_shear",      "ability_take_wing",       "utility_tailwind",
        "utility_manticore_wings", "utility_feral_instinct",  false,
        false,                    false,                     false,
    },
    -- Its dive as a cloak, and its cut as a hunter's ability. Ordered shallow to deep (docs/drops.md).
    drops = { "armor_plummet_cloak", "ability_gale_cut" },
    defaultAction = "weapon_wind_shear",
    archetype = "skirmish",
    ai = {
        -- Caught: go up. A wyvern with a foe beside it has lost its weapon and its Tailwind both.
        { priority = "high", act = "cast", item = "ability_take_wing",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
        -- Somebody is hurt: go up for them. The planner scores the dive off its forecast, and the forecast
        -- only pays when the mark is standing alone -- so it picks the lone one without being told to.
        { act = "cast", item = "ability_take_wing",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
