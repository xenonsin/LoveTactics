-- THE LERNAEAN HYDRA, a Crown elite (approved 2026-10-09, "The Crown's Bestiary", slice E). Theme: the Gate and
-- the End -- it guarded the way down at Lerna, and here it guards the bottom of this one.
--
-- TWO FOR ONE (utility_two_for_one, models/lerna.lua): three heads at the bell, one bite each (the jaws land once
-- per head, read off the Heads badge). A slash blow worth a tenth of its bar takes a head and two grow back, up to
-- six. Fire or Burn on it cauterises: for two turns a cut takes a head and nothing grows, and the last head never
-- comes off. How you beat it: bring impact, magic or fire. Burn it first and then cut. Don't open with swords.
--
-- A BEAST, 2x2, off the execute and Charm tables as every elite is. The heads are a count on the body rather than
-- bodies of their own (the Chimera's are units because each takes its own turn; these only add mouths).
--
-- FIELDED BY "LERNA" (the Hydra and a Chain Fiend), which the coordinator builds after the merge, since the fight
-- spans two slices. Nothing in this slice seats it.
--
-- WHAT IT HANDS OVER is all three of its pieces: Two Heads (the Barbarian's), Cauterise (the Crusader's) and
-- Hydra's Blood (the Poisoner's).
return {
    name = "Lernaean Hydra",
    race = "beast",
    tier = 4,
    boss = true,
    sprite = "assets/chars/lernaean_hydra.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 210, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 9, magicDamage = 0, -- low per bite: three to six of them land a turn
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 4,
        skill = 6, luck = 4,
    },
    -- Scaled: a point turns, a hammer finds the bone. The edge is left plain on purpose -- what a sword does to it
    -- is the heads, not the number.
    resist = { pierce = 2, impact = -2 },
    startingItems = {
        false, "weapon_hydra_jaws",  false,
        false, "utility_two_for_one", false,
        false, false,                 false,
    },
    drops = { "armor_two_heads", "ability_cauterise", "utility_hydras_blood" },
    defaultAction = "weapon_hydra_jaws",
    archetype = "aggressive",
}
