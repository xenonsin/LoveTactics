-- Shadow Trade: the mage half of the Ninja's Shadowclone (rogue x mage). Trade places with one of your
-- own doubles, anywhere on the field.
--
-- NAMED AROUND an existing item, and recorded here rather than hidden: this was drafted as "Shadow
-- Step", which data/items/ability/ability_shadow_step.lua has owned since long before the disciplines
-- existed -- a rogue base-shelf blink that jumps to a foe's side and cuts it. Same precedent as
-- "Duelist's Edge" -> "Duelist's Poise" (docs/disciplines-plan.md): the deeper cut yields the name to
-- the base shelf, because the shelf that is open from the first visit is the one whose vocabulary a
-- player learns first.
--
-- A SWAP rather than a blink, which is the better item anyway: a blink leaves nothing behind, while a
-- swap leaves the clone standing exactly where you were. Every use is therefore also a feint -- the line
-- closing on the ninja is now closing on a double, and the ninja is wherever it planted one three turns
-- ago.
--
-- Unlimited range, deliberately. The cost is not distance, it is foresight: you can only go where you
-- already spent mana to put a clone, so the ability is "was your plan good", asked one turn late. A
-- ninja with no double out has bought nothing.
--
-- fx.swap springs whatever waits on both tiles, so stepping onto a trap still costs you -- and stepping
-- your double onto one is a legitimate way to clear it.
return {
    name = "Shadow Trade",
    description = "Trades places with one of your clones, at any distance.",
    flavor = "He had been standing there the whole time. It simply had not been him.",
    sprite = "assets/items/ability_shadow_trade.png",
    type = "ability",
    tags = { "illusion", "utility" },
    class = "ninja",
    price = 165,
    unlockQuests = 1,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2, -- barely a beat: this is repositioning, not a working
        cost = { stat = "mana", amount = 6 },
        description = "Swaps you with one of your standing clones, wherever it is.",
        effect = function(fx)
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.decoyOf == fx.user and u ~= fx.user then
                    fx.swap(u)
                    return
                end
            end
            fx.log("action", "There is no double to step into.")
        end,
    },
}
