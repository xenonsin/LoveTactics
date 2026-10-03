-- SURGEON'S THREAD: the Patchwork's trophy (data/characters/character_patchwork.lua), on the Apothecary's shelf.
-- Approved on "Envy's Bestiary", round 1. The stitch in a company's hands: aimed at one foe within 3, it sews that
-- body to the nearest other foe within 3, and each is Conjoined to the other -- one link, the mage's binding at
-- two bodies. With no second foe in reach there is nothing to sew it to, and the cast says so.
--
-- 2 turns is 10 ticks (Status.TICKS_PER_TURN). It lands no damage of its own: the next blow is the payoff.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Surgeon's Thread",
    description = "Stitch two foes within 3 together: each is Conjoined to the other for 2 turns.",
    flavor = "The apothecaries learned it closing wounds. The Patchwork taught them what else a stitch will hold.",
    sprite = "assets/items/ability_surgeons_thread.png",
    type = "ability",
    tags = { "magical" },
    class = "apothecary",
    unlockLevel = 11,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 4,
        support = true, -- it lands no damage of its own: the binding is the whole cast
        cost = { stat = "mana", amount = 10 },
        effect = function(fx)
            local first = fx.target
            if not first then return end
            local second, best
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 3)) do
                if u ~= first and u.alive and u.side ~= fx.user.side then
                    local d = math.abs(u.x - first.x) + math.abs(u.y - first.y)
                    if not best or d < best then second, best = u, d end
                end
            end
            if not second then
                fx.log("action", "There is no second foe within reach to stitch it to.")
                return
            end
            -- ONE LINK for the pair, minted here and stamped on both ends, as Conjunction does: without it the
            -- binding would feed any other conjunction on the field. Conjoined is resistible, so an end that
            -- did not land is left unstamped.
            local link = {}
            for _, u in ipairs({ first, second }) do
                local st = fx.applyStatus(u, "status_conjoined", { duration = 10 })
                if type(st) == "table" then st.link = link end
            end
        end,
    },
}
