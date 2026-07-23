-- A greatsword, so it winds up (docs/weapons.md) -- but it winds up for ONE tick where the iron
-- greatsword takes two, and pays for the shorter telegraph with a condition: the blow only reaches its
-- full weight against a target already under half health. Against a fresh body it is a mediocre heavy
-- swing.
--
-- The family's entry-rank alternative, and the answer to what makes a greatsword hard to play: the
-- wind-up is a turn during which the target simply walks out of the aimed tile. A headsman's work does
-- not have that problem, because by the time the axe is raised the condemned is not going anywhere --
-- so the weapon that finishes the wounded is the one that can afford the shortest telegraph.
--
-- Reads directly against Saber's signature (data/items/weapon/weapon_first_motion.lua), which scales the
-- opposite way -- hardest into a FULL-health foe. The two are the same arithmetic with the sign flipped,
-- and a fighter carrying both has an opener and a closer rather than two greatswords.
return {
    name = "Headsman's Cleaver",
    description = "A short wind-up, then a heavy blow -- far heavier against a foe already under half health.",
    flavor = "The long wind-up is for people who might still move.",
    sprite = "assets/items/headsmans_cleaver.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    price = 340,
    repRank = 2,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 6,
        channel = 1, -- the shortest wind-up in the family: half the iron greatsword's telegraph
        cost = { stat = "stamina", amount = 13 },
        -- Well under the iron greatsword's curve: this is what it lands into a HEALTHY target, and the
        -- bonus below is what it lands into the wounded one it is actually for.
        damage = { 14, 16, 17, 19, 20, 22, 23, 25, 26, 28, 30 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local health = t.char and t.char.stats and t.char.stats.health
            local hurt = health and health.max > 0 and (health.current / health.max) < 0.5
            -- +80% into the wounded. Large on purpose: the condition is read off the board before the
            -- wind-up is committed, so a player who lines this up correctly should be rewarded for the
            -- read rather than for the roll.
            fx.damage(t, hurt and { amount = math.floor(fx.amount * 1.8) } or nil)
        end,
    },
}
