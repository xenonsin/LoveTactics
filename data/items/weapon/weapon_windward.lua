-- A bow, so it shoots at range and has no point-blank shot (docs/weapons.md). Its extra is that it wants
-- to be as close to that dead zone as it can get: the shot is hardest at exactly minRange and falls off
-- for every tile past it.
--
-- Quest-only: `class` with no `price`.
--
-- The exact inverse of data/items/weapon/weapon_hornbow_of_the_hunt.lua, which adds a fifth of the shot
-- for every tile past point-blank and wants the whole field between the archer and the kill. Both are
-- deviations from how a bow is normally played, in opposite directions, and having both on the shelf is
-- what turns "stand at maximum range" from the correct answer into a question.
--
-- What it produces is an archer standing two tiles from a melee -- inside the enemy's charge range, one
-- step from being closed on, and inside its own dead band the moment anything reaches it. That is a
-- genuinely dangerous place for a hunter to stand and it is the only place this bow is good. It is the
-- Lodge's argument that distance is a habit rather than a virtue.
--
-- Not a deviation from the family CONTRACT: it keeps range 3 and minRange 2 like any bow, so the dead
-- zone is intact and it still cannot answer a foe in its face. Only the damage curve is inverted.
return {
    name = "Windward",
    description = "Fires at range, hitting hardest at the very edge of its dead zone and weaker with every tile past it.",
    flavor = "The Lodge teaches distance first because distance is easy to teach. This one is for afterwards.",
    sprite = "assets/items/windward.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2, -- the family's dead zone, kept: this is not a melee weapon, it is an impatient bow
        requiresSight = true,
        speed = 2,
        cost = { stat = "stamina", amount = 7 },
        -- Read as the CLOSE number: this is what it lands at two tiles, and it is well above an iron
        -- bow's. Every tile further gives a quarter of it back.
        damage = { 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- -25% per tile beyond the dead zone, floored at a third so a long shot is a bad shot rather
            -- than a wasted turn. Manhattan distance, as every range check in this game uses.
            local dist = math.abs(t.x - fx.user.x) + math.abs(t.y - fx.user.y)
            local past = math.max(0, dist - 2)
            local share = math.max(0.34, 1 - 0.25 * past)
            fx.damage(t, { amount = math.max(1, math.floor((fx.amount or 0) * share)) })
        end,
    },
}
