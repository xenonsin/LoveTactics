-- BLOOD DEBT: the Pit Imp's Offer, and the Warlord's Signed in Blood ("The Crown's Bestiary", slice B, 2026-10-09).
-- +5 damage for 2 turns, and the bearer runs up a ledger of every point it deals meanwhile (Combat.dealFlatDamage,
-- models/crown_demons.lua's noteDealt). When the debt RUNS OUT it comes due: a third of that ledger, straight off
-- the bearer's health. Cure it off first and it is never paid -- the instance is removed with time still on it, and
-- only a debt whose time is up is charged.
--
-- NOT OWED, which sits beside it on Greed's floors: Owed makes every blow on its bearer land harder, stack by
-- stack. This charges its bearer for the blows it landed. A debuff, so Cure lifts it, which is the counter.
return {
    name = "Blood Debt",
    abbr = "BDbt",
    description = "Blood Debt: +5 damage. When it ends, takes a third of the damage dealt under it.",
    color = { 0.620, 0.090, 0.140 }, -- badge tint (a signature's dried red)
    duration = 10, -- 2 turns at Status.TICKS_PER_TURN
    debuff = true, -- removable by Cure, before it comes due
    statBonus = { damage = 5 },
    onExpire = function(ctx) require("models.crown_demons").settleDebt(ctx) end,
}
