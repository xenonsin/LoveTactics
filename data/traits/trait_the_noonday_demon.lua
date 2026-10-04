-- LISTLESS: the Noonday Demon's rule (utility_noonday_haze; "Sloth's Bestiary", 2026-10-04, slice C). The desert
-- fathers' daemon meridianus, the demon of the long afternoon that makes a monk stare at the sun and wonder why he
-- bothers. Each foe within 4 that ends its turn having dealt no damage gains Listless (-3 Damage a stack); at 3
-- it is Shamed on its next turn; dealing damage clears every stack (models/sloth_bog.lua, status_listless).
--
-- Heard on every foe's turn end (Trait.onAnyTurnEnd). Its prey is the healer and the support, who fight least:
-- keep them more than 4 away from it, or give them something to hit. `notAReaction`: a stunned demon's
-- afternoon is no shorter.
return {
    name = "Listless",
    description = "Foes within 4 that end their turn having dealt no damage gain Listless. At 3, they are Shamed.",
    reach = 4,
    notAReaction = true,
    onAnyTurnEnd = function(ctx)
        require("models.sloth_bog").idleTurn(ctx.combat, ctx.unit, ctx.actor, ctx.param("reach", 4), true)
    end,
}
