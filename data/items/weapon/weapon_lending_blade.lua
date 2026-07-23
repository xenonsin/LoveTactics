-- A sword, so it answers -- and it is the one sword in this batch that keeps the ORDINARY Parry
-- (docs/weapons.md). Its extra is on the strike instead: the blow takes the target's guard away
-- (status_given_guard) and hands that guard to an ally standing beside the swordsman
-- (status_lent_guard). Armour does not get destroyed here, it gets MOVED.
--
-- Quest-only: `class` with no `price`.
--
-- The two statuses were built as a matched pair for exactly this -- Given Guard is a flat -6 defense and
-- Lent Guard the same number with the sign flipped, so the ledger balances and nothing is created. What
-- the weapon sells is the choice of WHO: it needs a friend adjacent to be worth anything, which makes it
-- the only sword in the game that is weaker when you fight at the front alone. Swing it with nobody
-- beside you and the guard you took simply evaporates, and the blade is an iron sword.
--
-- Reads against data/items/weapon/weapon_wardens_tongue.lua, which is the same "the line gets it too"
-- sentence spoken through the reflex rather than the swing: that one pays out when the ENEMY commits,
-- this one when you do.
return {
    name = "The Lending Blade",
    description = "Strikes an adjacent foe, stripping their guard and lending it to an ally beside you.",
    flavor = "Nothing is destroyed and nothing is made. The armour simply changes its mind about whom it belongs to.",
    sprite = "assets/items/lending_blade.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1,
    traits = { "trait_parry" }, -- the plain Parry: this blade's extra is the swing, not the answer
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = { 5, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_given_guard")
            -- ...and the guard has to land on somebody. The FIRST living ally beside the swordsman, not
            -- the best one: choosing the recipient is the player's job, and they do it by standing
            -- somewhere. With nobody adjacent the loan simply is not made -- the strip still happens, so
            -- the blade is never worse than an ordinary sword, only less than itself.
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u ~= fx.user and u.alive and u.side == fx.user.side then
                    fx.applyStatus(u, "status_lent_guard")
                    break
                end
            end
        end,
    },
}
