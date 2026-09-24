-- INTEREST: Greed's slime rule, and the badge a company reads it off (data/traits/trait_interest.lua).
--
-- Every turn its bearer starts, the principal compounds: `step` more Damage and `gold` more in the purse,
-- for at most `cap` turns. When the bearer falls the purse is banked on the fight (Combat.bounty) and paid
-- only on a win. So the swamp's slimes put a price on patience -- kill one at once and it is cheap and
-- poor; leave it to grow and it hits harder and pays more. Greed as a decision rather than a tax, which
-- is the same bargain the stair's toll makes one floor over.
--
-- The instance carries its own terms (`step`, `gold`, `cap`, `paysNow`), stamped by the trait that
-- opened the account, because one status serves four granters: the two slimes, the Ledger Coin (growth
-- with no purse) and the Compound Purse (a purse paid each turn rather than on death).
return {
    name = "Interest",
    abbr = "Int",
    description = "Compounding: more Damage each turn, and a fuller purse when it falls.",
    color = { 0.811, 0.700, 0.335 }, -- badge tint (coin gold, greed's colour -- as On Account)
    duration = math.huge,
    hideDuration = true,
    magnitude = 0,
    magnitudeStat = "damage",
    onTurnStart = function(ctx)
        local s = ctx.status
        local turns = s.turns or 0
        if turns >= (s.cap or 6) then return end
        s.turns = turns + 1
        s.magnitude = (s.magnitude or 0) + (s.step or 0)
        local gold = s.gold or 0
        if gold > 0 then
            if s.paysNow then
                require("models.combat").bounty(ctx.combat, gold)
            else
                s.purse = (s.purse or 0) + gold
            end
        end
    end,
    onDeath = function(ctx)
        local s = ctx.status
        if s.passed or s.paysNow or (s.purse or 0) <= 0 then return end
        require("models.combat").bounty(ctx.combat, s.purse)
        ctx.log("action", string.format("%s spills %d gold.",
            (ctx.unit.char and ctx.unit.char.name) or "It", s.purse))
    end,
}
