-- A greatsword, so it winds up (docs/weapons.md). Its extra is what the wind-up is FOR: when the blow
-- lands, the turn it cost is handed to an ally standing beside the wielder -- they get an extra action
-- (Combat.grantExtraAction), taken immediately, with no enemy beat in between.
--
-- Quest-only: `class` with no `price`.
--
-- The greatsword's whole economy is that it spends tempo to buy weight. Every other weapon in the family
-- keeps both halves of that bargain to itself. This one splits it: the wielder still pays the two ticks
-- of raise and still lands a heavy blow, and the *party* gets the turn back somewhere else. A fighter
-- swinging this is a fighter setting up the rogue's opening.
--
-- Read the honest shape of the gift in docs/weapons.md ("The extra action"): what it buys is ORDER, not
-- time. Every tick the granted action would have cost is banked as Combat.tempoDebt and paid in full when
-- that ally next stops, so the ally is not given a free turn -- they are given tomorrow's turn today, and
-- they get it while the greatsword's target is still reeling. Two allied actions with nothing between
-- them is what burst has always been, and this is the only weapon in the game that hands it to somebody
-- else.
--
-- It grants no second walk (the turn re-opens with the move already spent), and with nobody adjacent it
-- is simply a slightly weak greatsword -- the same "you pay for it by standing somewhere" clause
-- data/items/weapon/weapon_lending_blade.lua runs on.
return {
    name = "The Given Hour",
    description = "Winds up, then falls on one tile -- and hands the turn it cost to an ally beside you.",
    flavor = "He never did work out what to do with the hour. He was, by then, extremely good at giving it away.",
    sprite = "assets/items/given_hour.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        channel = 2,
        cost = { stat = "stamina", amount = 16 },
        -- Under the iron greatsword's: an ally's whole action is worth more than the six points of Power
        -- it gives up, and it should be, or nobody would ever swing the plain one.
        damage = { 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 39 },
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end
            local Combat = require("models.combat")
            -- The FIRST living ally beside the wielder, not the best one. Choosing who gets the hour is
            -- the player's job and they do it by standing somewhere, exactly as the Lending Blade's loan
            -- is aimed by position rather than by a menu.
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u ~= fx.user and u.alive and u.side == fx.user.side then
                    Combat.grantExtraAction(u, 1)
                    fx.log("action", string.format("%s gives the hour to %s!",
                        (fx.user.char and fx.user.char.name) or "Unit",
                        (u.char and u.char.name) or "an ally"))
                    break
                end
            end
        end,
    },
}
