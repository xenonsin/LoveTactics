-- THE LESSER RITE: what the Cathedral does in town, done in the field by somebody who earned the right
-- (models/curse.lua, docs/curses.md).
--
-- THE PLAYER-SIDE ANSWER TO A CURSE, and it is gated by machinery that already exists: an ability is
-- priced, a priced item is shelf-gated on `unlockQuests`, and Quest.shelfRung reads the roster's best
-- PRIEST class level for the Cathedral's rack. A company that never played the priest never sees this
-- and pays the room. Lifting is something a priest earns.
--
-- THE ROOM STAYS OPEN TO EVERYBODY ANYWAY, which is the law this could have broken. docs/the-count.md:
-- a cost on recovery is a tax on needing to recover. The Cathedral's rite is free-and-slow for any
-- company, priest or not; what a high priest buys is SPEED and REACH -- the hex comes off here, now,
-- underground -- and never relief itself.
--
-- IT BURNS AS IT LIFTS, which is what makes it an ability rather than housekeeping. The binding does not
-- simply stop: it comes apart, and coming apart is holy damage to everything standing around the body it
-- was riding. A rite cast into a crowd is a real play, and the company's own curses are what load it.
--
-- AND IT WORKS OUTSIDE A FIGHT (`outOfCombat`), which is the whole reason that system exists. On the map
-- it is the lift alone -- there is nobody to burn -- and in a fight it is both. One ability, not two.
local Curve = require("models.curve")

return {
    name = "The Lesser Rite",
    description = "Lifts one hex from an ally's kit; in a fight the binding bursts for holy damage.",
    flavor = "Nine words. The first eight are an apology to whatever is about to be evicted.",
    sprite = "assets/items/ability_lesser_rite.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "exorcist",
    price = 565,
    unlockLevel = 11,
    activeAbility = {
        target = "ally",
        range = 2,
        aoe = { radius = 1, shape = "square" },
        speed = 6,
        cost = { stat = "mana", amount = 12 },
        damage = Curve.ramp(15, 25),
        outOfCombat = true,
        -- THE ROAD VERSION, and it is a smaller spell on purpose (Player.castOutOfCombat's roadCtx).
        -- In a fight this lifts and BURSTS; out here there is nobody standing around the body to burn,
        -- so what is left is the lift -- which is the whole reason a priest is worth walking down with.
        roadEffect = function(ctx)
            return ctx.liftCurse(ctx.target)
        end,
        description = "Lifts one hex from an ally's kit; in a fight the binding bursts for holy damage.",
        effect = function(fx)
            local t = fx.target
            if not (t and t.char) then return end
            local Curse = require("models.curse")
            local worst = Curse.deepestOn(t.char)
            if not worst then return end
            Curse.lift(worst)
            -- The burst. Enemies only -- a rite does not punish the line it was cast to help.
            for _, u in ipairs(fx.aoeUnits() or {}) do
                if u.side ~= fx.user.side then fx.damage(u, { tags = { "holy" } }) end
            end
        end,
    },
}
