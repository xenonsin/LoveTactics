-- Ilan's bound relic (Theurge). He says the long version.
--
-- YOU CHOOSE HOW LONG TO WAIT, and both sides of the board pay for it in opposite directions: when the
-- prayer finally lands, every ally is healed and every enemy is struck, each scaled by the turns he
-- held it. Nothing else in the game asks the player to price patience on both ledgers at once.
--
-- NO NEW MACHINERY. `windup = { max }` is the existing chargeable wind-up -- the tile-anchored slider
-- that previews each depth live -- already carried by First Motion, Avalanche, the Warden's Longbow and
-- The Held Reaction. That last one is an ability rather than a weapon, so a non-weapon wind-up was
-- already proven before this file existed.
--
-- AND IT CANNOT BE BROKEN. `steadfast` opts out of Combat.interruptChannel, which every knockback path
-- and seven statuses already call -- so Vigil Beads, the shelf item that protects a channel, becomes
-- the cheap partial version of this relic's first clause rather than a rival to it. Litany Staff
-- scales holy damage with channel length and multiplies the same number twice.
local Curve = require("models.curve")

return {
    name = "The Unbroken Vigil",
    description = "A prayer nothing can break. Hold it as long as you dare; it heals your side and burns theirs by the waiting.",
    flavor = "The short version is for people who expect to be interrupted.",
    sprite = "assets/items/sig_unbroken_vigil.png",
    type = "utility",
    tags = { "signature", "holy" },
    class = "priest",
    discipline = "theurge",
    bound = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "mana", amount = 14 },
        aoe = { radius = 3, shape = "square" },
        -- The chooser: one tick at a minimum, six at the outside. Every extra tick is a turn the board
        -- gets to walk out of the footprint, which is what makes the depth a decision rather than a
        -- slider you always push to the end.
        windup = { min = 1, max = 6 },
        steadfast = true, -- nothing shatters it: the relic's first clause
        --        level:  0  1  2  3  4  5  6  7   8   9  10
        damage = Curve.ramp(8, 20),
        description = "Heals allies and burns foes within 3, scaled by how long you held it.",
        unlock = {
            field = { of = "unit", side = "ally", hpBelow = 1, count = 3 },
            text = "3 allies wounded",
        },
        effect = function(fx)
            -- The depth is what was actually held. `fx.held` is the chooser's number in a live cast and
            -- 0 in the tooltip's dry run, so the floor of 1 keeps the preview honest rather than blank.
            local depth = math.max(1, fx.held or fx.windup or 1)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side == fx.user.side then
                    fx.heal(u, fx.amount * depth)
                else
                    fx.damage(u, { amount = fx.amount * depth, tags = { "holy" } })
                end
            end
        end,
    },
}
