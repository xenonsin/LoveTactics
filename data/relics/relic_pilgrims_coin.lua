-- VIRTUE · overworld · common. A blessed coin that keeps a little of every victory. The gentlest relic
-- on the shelf: a small, reliable trickle that rewards clearing fights at all.
return {
    name = "Pilgrim's Coin",
    blurb = "A little gold after every fight won.",
    tier = "common", alignment = "virtue", affinity = "overworld", weight = 3,
    encounterCleared = function(_, _, ctx)
        ctx.addGold(8)
        ctx.say("Pilgrim's Coin  +8g")
    end,
}
