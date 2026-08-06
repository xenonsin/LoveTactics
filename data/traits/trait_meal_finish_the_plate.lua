-- Finish the Plate: the kitchen skill on the Carver's Plate. Blows land harder on anything
-- already down past half its health.
--
-- Monster Hunter's Felyne Slugger, redirected. Slugger sharpens stun, which in a tactics game is a
-- status somebody else's item inflicts, so pointing a food skill at it would be a buff most companies
-- could not use. What survives the move is the SHAPE: a skill that pays only in the part of the fight
-- where you are already committed. Here that is the wounded body -- the one everyone is converging on
-- and the one that will otherwise get a turn it should not have had.
--
-- Deliberately NOT an execute. The rogue's shelf owns that word (docs/classes.md), and an execute is a
-- threshold that kills; this is a flat plus that shortens the last exchange by one swing. On a board
-- where a fallen body starts a countdown rather than dying outright, closing a kill a turn earlier is
-- worth a great deal and is still not the same purchase.
--
-- Rides `damageBonusVs` (Trait.outgoingDamageBonus), so it reads every strike the bearer makes -- a
-- weapon, a spell, a thrown flask -- rather than one weapon family. Half is measured off the target's
-- own bar, unreserved max included, so a body that has locked health away is judged on what it actually
-- has left rather than on the ceiling it started the campaign with.
return {
    name = "Finish the Plate",
    description = "Strikes land harder against anything already below half its health.",
    amount = 5,
    damageBonusVs = function(ctx)
        local tgt = ctx.target
        local hp = tgt and tgt.char and tgt.char.stats and tgt.char.stats.health
        if type(hp) ~= "table" then return 0 end
        local max = require("models.combat").unreservedMax(tgt.char, "health")
        if max <= 0 then return 0 end
        if (hp.current or 0) / max >= 0.5 then return 0 end
        return ctx.def.amount or 5
    end,
}
