-- WANTING COSTS: whoever damages it catches fire. At any range, by any means.
--
-- THE CIRCLE'S FIFTH VERB, FIELDED AT LAST. models/descent.lua's Lust entry lists five things this
-- stratum does and glosses the fire one as "...and wanting costs, whether or not you get there." Until
-- this trait it was prose: the only fire on the ground was a rider on the harpy's talons, which is fire
-- arriving the ordinary way -- something hit you. Nothing charged a company for REACHING.
--
-- SO IT IS THE OPPOSITE OF EVERY OTHER BURN IN THE GAME, and the inversion is the whole design. A
-- cinder-kin burns what it hits (data/items/weapon/weapon_cinder_brand.lua); Wrath's whole stratum
-- burns the ground you have to stand on. This burns what reaches for IT -- the arrow as readily as the
-- axe, the spell as readily as the arrow -- so there is no stand-off distance at which answering it is
-- free. Distance is the one currency this circle has never charged in, and this is the body that does
-- not take it.
--
-- THERE IS EXACTLY ONE FREE ANSWER, AND IT IS THE ENGINE'S RULE RATHER THAN THIS TRAIT'S: KILL IT WITH
-- THE BLOW. A reflex is held while a cast resolves and the flush skips the fallen (Combat.endAnswers --
-- `if a.unit.alive`), so a Fire Elemental that goes down to the hit that reached it bills nobody at all. That
-- is not a leak, it is the whole lesson of a lamp room, and it is why these are authored thin: a
-- company that commits and puts one out in a single action pays nothing, and a company that chips
-- carefully at four of them pays four times. This circle has spent two floors teaching patience and
-- position. The answer here is to be quick.
--
-- NOT A COUNTER, DELIBERATELY, and the two differences are both load-bearing. It pays no stamina and
-- takes no reach gate: `counter = { reach = "melee" }` is a body ANSWERING a blow (Antler Toss, Shield
-- Shove, Downdraft), and a candle does not answer anything -- it is simply hot, and the hand came to
-- it. The escalating answer price (Trait.answerCost) that paces the reflexes would also be wrong here
-- for the same reason: a flame does not get tired of being touched.
--
-- WHAT PACES IT INSTEAD IS BURN'S OWN REFRESH. Status.apply refreshes a duration rather than stacking
-- it (tests/status_spec.lua), so a party that pounds one Fire Elemental flat in a turn takes ONE burn between
-- them all rather than four -- the rule bills the first blow and the rest are free. That is what keeps
-- a free, uncapped retaliation from being an unanswerable one, and it is why the answer to a lamp room
-- is to kill them fast rather than carefully.
--
-- `notAReaction` SO A STUN DOES NOT PUT IT OUT. reactionsSuppressed skips onDamaged for a rattled body,
-- which is correct for a reflex and wrong for a property: a Fire Elemental that has been stunned is a stunned
-- thing that is still on fire. Trait.onDamaged's own header makes this distinction for boss phases and
-- it is the same distinction.
return {
    name = "Wanting Costs",
    description = "Whoever damages it catches fire.",
    notAReaction = true, -- being hot is not an answer, so a stun does not silence it
    onDamaged = function(ctx)
        local a = ctx.attacker
        if not (a and a.alive) then return end
        if a.side == ctx.unit.side then return end -- friendly fire does not feed it
        ctx.applyStatus(a, "status_burn")
    end,
}
