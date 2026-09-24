-- THE MOSS SLOUGHLING: a piece of somebody, standing up on its own for a while.
--
-- The one small body every moss-slime drop puts on the board -- the Mosswrap sloughs one off a hurt
-- bearer (trait_slough), the Crown of the Court calls two (utility_crown_of_the_court), and the Moss
-- Heart comes apart into three (trait_come_apart). All three are the Gluttony slimes' own rule handed to
-- a company: what came apart tries to come back together. So it is summoned with its maker as its
-- summoner, walks home under the `gather` posture, and gives its remaining health back with Rejoin the
-- moment it stands beside them (Combat.rejoin).
--
-- Tier 1 and soft: its health is set by whoever made it (Summon.spawn's `stats`), and the blueprint's
-- own figure is only a fallback. It fights on the way if something is in reach -- a piece of a body is
-- still that body -- but its whole job is the walk back.
return {
    name = "Moss Sloughling",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/moss_sloughling.png",
    stats = {
        health = 12, mana = 0, stamina = 10,
        staminaRegen = 2,
        damage = 6, magicDamage = 0,
        defense = 1, magicDefense = 1,
        movement = 4,
        speed = 5,
        skill = 3, luck = 2,
    },
    -- The moss slime's own elemental trade, a rung smaller (Balance.INNATE_BUDGET allows 2 at tier 1).
    resist = { acid = 2, ice = -2 },
    startingItems = {
        false,              "ability_rejoin",     false,
        "weapon_pseudopod", "utility_mossy_body", false,
        false,              false,                false,
    },
    defaultAction = "weapon_pseudopod",
    archetype = "gather",
}
