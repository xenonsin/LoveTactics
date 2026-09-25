-- HIRE A HAND: the Hoard-Thane spends his coffer on another pair of arms. Approved on the Thane's row
-- (2026-09-24): "he spends his coffer to hire: at 30 gold a Delver surfaces beside him".
--
-- 30 GOLD OUT OF HIS OWN COFFER (Combat.spendPurse is side-aware: an enemy spends unit.coffer), and the
-- hand is a SUMMON -- so when the Thane falls the pay stops and every hired hand leaves the field with
-- him. That is the tell and the answer at once: the hands are only as good as the purse behind them.
--
-- Unusable below the price (the `usable` gate), so a Thane the company has kept poor never hires at all
-- -- which is what killing the line early buys, and what every Share he inherits costs.
local PRICE = 30

return {
    name = "Hire a Hand",
    description = "Consume 30 gold from your coffer: a Dwarf Delver surfaces beside you, and leaves when you fall.",
    flavor = "\"Half now. The other half if you're alive to ask for it.\"",
    sprite = "assets/items/ability_hire_hand.png",
    type = "ability",
    tags = { "guile" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        cooldown = 15,
        usable = function(unit)
            if (unit.coffer or 0) < PRICE then return false, "Not enough gold" end
            return true
        end,
        effect = function(fx)
            local x, y = fx.openTileNear(fx.user.x, fx.user.y)
            if not x then return end
            if fx.spendPurse(PRICE) < PRICE then return end
            fx.summon("character_dwarf_delver", x, y, { noClaim = true })
        end,
    },
}
