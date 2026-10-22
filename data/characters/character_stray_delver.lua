-- THE STRAY DELVER, unrolled: what an encounter names when it puts a stranger in trouble on the board
-- (`allies = { "character_stray_delver" }`). Arena.build never seats this body -- it rolls a
-- `character_stray_delver@<class>.<race>.<roll>` off the fight's seed in its place (models/delver.lua),
-- a hire's body with this one's posture. This file is what everything that RATES a fight without
-- seating it reads instead: a fighter-shaped stranger at the class standard, so a muster does not
-- price the charge at nothing.
--
-- Posted where it stands (`holdGround`): a body an objective is staked on, posted to nothing else
-- (models/ai.lua; the caravan master's lesson). A rescue's captive walks once it is cut free -- the
-- objective hands it the escort's walk (AI.plan), not its blueprint.
return {
    name = "Stray Delver",
    race = "human",
    tier = 2,
    delver = true,
    archetype = "holdGround",
    sprite = "assets/chars/stray_delver.png",
    stats = {
        health = 60, mana = 20, stamina = 20,
        staminaRegen = 2,
        damage = 8, magicDamage = 2,
        defense = 4, magicDefense = 3,
        movement = 3,
        speed = 4,
        skill = 5, luck = 5,
    },
    -- A sword off the bottom shelf, so a rated fight prices a body that can answer a blow. The rolled
    -- variant carries its own class's rung-0 kit instead (Hire.kitOf).
    startingItems = { "weapon_iron_sword" },
    defaultAction = "weapon_iron_sword",
}
