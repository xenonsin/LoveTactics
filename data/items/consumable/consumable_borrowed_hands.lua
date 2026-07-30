-- Borrowed Hands: the Apothecary's elixir (priest x alchemist). Drink it and your magic attack becomes
-- the highest in the party, for the rest of the battle.
--
-- The elixir-that-lends-you-somebody-else's-stat that docs/classes.md has described as this shelf's
-- voice since before the shelf could sell one. Its damage number is not authored anywhere in this file:
-- it is a readout of your own party, so the item is worth exactly as much as the best caster you brought
-- and nothing at all to a party of one. That is envy priced correctly.
--
-- It is also self-balancing in a way a flat number could never be. An apothecary travelling with Gyeom
-- drinks a great deal; one travelling alone drinks water. Nobody has to retune it when the roster
-- changes, and no forge level can inflate it past the party it is measured against.
--
-- Battle-long rather than timed, stated plainly rather than fudged: the bonus is written onto the unit's
-- own `bonus` table (never the shared character instance, so it does not follow anyone home), and there
-- is no clock on it. A three-turn version would want a status carrying a magnitude computed at drink
-- time, which the status layer has no shape for -- and the honest read is that a fight is short enough
-- that "the rest of it" and "three turns" are usually the same sentence.
return {
    name = "Borrowed Hands",
    description = "Raises your Magic Damage to the highest in your party this battle.",
    flavor = "It is not that she cannot do it herself. It is that somebody nearby does it better.",
    sprite = "assets/items/consumable_borrowed_hands.png",
    type = "consumable",
    -- No `potion` tag: the Market resells anything wearing it and ignores standing entirely, so a
    -- gated elixir tagged `potion` would be on the grocer's shelf turn one (docs/classes.md).
    tags = { "elixir" },
    class = "alchemist",
    discipline = "apothecary",
    price = 160,
    unlockQuests = 10,
    maxStack = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        consumesItem = true,
        description = "Raises your Magic Damage to the party's highest.",
        effect = function(fx)
            local best, mine = 0, 0
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.char and u.char.stats and u.char.stats.magicDamage then
                    local v = u.char.stats.magicDamage
                    if u == fx.user then mine = v end
                    if u.side == fx.user.side and v > best then best = v end
                end
            end
            local gain = best - mine
            if gain <= 0 then
                fx.log("action", "There is nobody here worth borrowing from.")
                return
            end
            -- Bank a fresh COPY of the bonus table, never a mutation of the live one: the damage
            -- preview replays this effect on every hover/aim frame, and an in-place `fx.user.bonus.x +=`
            -- would ratchet the real caster's magic attack up each frame. Copy, add, then hand it to
            -- fx.bank (real on the live cast, inert in the preview), so the raise lands once, on use.
            local bonus = {}
            if fx.user.bonus then for k, v in pairs(fx.user.bonus) do bonus[k] = v end end
            bonus.magicDamage = (bonus.magicDamage or 0) + gain
            fx.bank("bonus", bonus)
            fx.log("action", string.format("Borrowed hands: magic attack raised by %d.", gain), fx.user)
        end,
    },
}
