-- THE KINSLAYER: Envy's seat-floor elite (reviewed 2026-10-01..03, "Envy's Bestiary", row kn_body, approved, and
-- named "the Kinslayer" from the page's candidates). The first envy and the first murder: an elder brother whose
-- offering was refused, and who has kept count of everyone else's ever since. The review renamed him ("too direct
-- to the bible") and moved him off the stair to an elite; no name from the old story appears anywhere in his kit.
--
-- HIS RULES ride on his organ (utility_kinslayers_grudge), and models/kinslayer.lua argues them: he hunts THE
-- FAVOURED ONE, the body of the company healed or blessed most this fight, shown by a counter (status_favoured);
-- and THE MARK -- whoever lands his killing blow takes 7 times his last hit. Spread your healing, and finish him
-- with a summon, a bomb, a hazard or a burn.
--
-- Human, which the waste fields only as a named elite, never as traffic; no class, so he grows on the fighter's
-- fallback table like every unclassed body. A mace for the first blow ever struck in anger. Tier 4 by the
-- review's tag; `boss`, off the execute and Charm tables like every elite.
return {
    name = "The Kinslayer",
    race = "human",
    tier = 4,
    boss = true,
    sprite = "assets/chars/the_kinslayer.png",
    stats = {
        health = 165, mana = 0, stamina = 34,
        staminaRegen = 5,
        damage = 15, magicDamage = 0,
        defense = 8, magicDefense = 5,
        movement = 4,
        speed = 4,
        skill = 8, luck = 5,
    },
    startingItems = {
        false, "weapon_iron_mace",           false,
        false, "utility_kinslayers_grudge",  false,
        false, false,                        false,
    },
    -- His own piece (docs/drops.md): the Mark, worn by whoever carries it out.
    drops = { "utility_the_mark" },
    defaultAction = "weapon_iron_mace",
    archetype = "aggressive",
}
