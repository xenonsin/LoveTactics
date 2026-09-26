-- GILDED BREAD: the second of the Gilded King's two trophies (2026-09-26, the author's words: "Cannot be
-- healed. Activate ability to use your own money to heal a target. 1HP is 5 gold."). The loaf that starved
-- him, carried out of his vault: it will not feed the one who holds it, and it will feed anybody else.
--
--   GOLD IN THE MOUTH  its bearer cannot be healed, by anything, in a fight (trait_gold_in_the_mouth)
--   THE BREAD          pay the company's own gold to heal an ally, FIVE GOLD A POINT, dialed at the cast on
--                      the Gilded Wound's slider (`purchase`, ui/panels/spend_chooser.lua), up to 30 a cast
--
-- The purse seam the whole money kit spends through (fx.purse / fx.spendPurse, docs/classes.md): real gold,
-- gone for good, and inert outside a campaign fight. It pays for POINTS HEALED and never for points
-- offered -- the dial is clamped to the target's missing health and to what the purse holds, so a full
-- body costs nothing and a heal the target cannot take is never bought (Combat.healRefusal: a body that
-- refuses healing, turns it to gold, or would be burned by it is refused BEFORE a coin moves). That clause
-- is also what keeps it from being a cheaper Gilded Wound against the dead, or a gold press on the King.
--
-- MAMMONITE, like every piece that spends the purse (tests/purse_spec.lua's MONEY_KIT). Unstocked
-- (tests/discovery_spec.lua's TROPHIES): seen on the rack, never sold.
local RATE = 5

return {
    name = "Gilded Bread",
    description = "You cannot be healed. Spend gold to heal an ally: five gold a point, dialed at the cast.",
    flavor = "He could not eat it. Anyone else can.",
    sprite = "assets/items/ability_gilded_bread.png",
    type = "ability",
    tags = { "guile", "restorative" }, -- guile: the rogue's word; the purse is the header's business
    class = "mammonite",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_gold_in_the_mouth" },
    activeAbility = {
        target = "ally",
        range = 3,
        speed = 3,
        support = true,
        cost = { stat = "stamina", amount = 3 }, -- a token effort; the purse is the true cost
        -- `perDamage` is the chooser's exchange rate whatever the coin buys; `unit` names what it buys.
        purchase = { perDamage = RATE, max = 30, unit = "hp" },
        description = "Spend up to 150 gold; each 5 gold heals the target one point. Pays only for what it heals.",
        effect = function(fx)
            local t = fx.target
            if not (t and t.char) then return end
            local Combat = require("models.combat")
            -- A heal that could not land is not bought (see header).
            if Combat.healRefusal(t) then return end
            local hp = t.char.stats.health
            local missing = math.max(0, Combat.unreservedMax(t.char, "health") - hp.current)
            local points = math.min(math.floor((fx.spend or 0) / RATE), missing,
                math.floor((fx.purse or 0) / RATE))
            if points <= 0 then return end
            local paid = fx.spendPurse(points * RATE)
            local bought = math.floor(paid / RATE)
            if bought > 0 then fx.heal(t, bought) end
        end,
    },
}
