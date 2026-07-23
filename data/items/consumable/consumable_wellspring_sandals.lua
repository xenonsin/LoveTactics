-- Wellspring Sandals: worn thin at the sole, and worth more to the people standing next to you than to
-- you. Every ally within reach gets mana back at once.
--
-- MANA DOES NOT REGENERATE IN THIS GAME. That is a hard rule with exactly one standing exception (an
-- Arcane Reservoir bearer, at one point a tick -- see Combat.ARCANE_REGEN), and the rule is what makes
-- every mage turn a real decision rather than a rotation. So a party-wide refill is a large thing to
-- sell, and everything about how this is priced follows from that.
--
--   * It costs a WHOLE TURN, from somebody, and it heals nobody. In a fight that is going badly, that
--     turn was needed elsewhere -- which is what stops this being a free tax on the enemy's patience.
--   * It is a CONSUMABLE STACK, not a permanent charm. Three uses a battle, and then it is an empty
--     slot until it is restocked at the Market.
--   * It pays out at radius 1, so the party has to be standing together -- the same formation this
--     game's area damage exists to punish.
--
-- What it actually buys is a second Fireball, or a second seal, or the Stilled Hour the mage could not
-- otherwise afford. In a two-caster party it is one of the strongest items on this list; in a party of
-- fighters it is a slot somebody wasted, and the shop tooltip is quite honest about which.
return {
    name = "Wellspring Sandals",
    description = "Restores mana to the bearer and every ally standing beside them.",
    flavor = "Somebody walked a very long way in these, and did not arrive anywhere in particular.",
    sprite = "assets/items/consumable_wellspring_sandals.png",
    type = "consumable", -- a stack: three uses, then an empty slot until it is restocked
    tags = { "arcane" },
    price = 220, -- no class: the Market's shelf, and every party wants one
    repRank = 2,
    maxStack = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        consumesItem = true,
        support = true,
        effect = function(fx)
            local given = 14 + 2 * fx.level
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u.side == fx.user.side then
                    fx.restore(u, "mana", given)
                end
            end
            fx.log("action", string.format("%s draws the wellspring up (%d mana each).",
                fx.user.char and fx.user.char.name or "Unit", given), fx.user)
        end,
    },
}
