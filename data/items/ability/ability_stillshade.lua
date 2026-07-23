-- Stillshade: the rogue stops moving, and stops being there. It holds until they do something -- and
-- the something it breaks on lands on a body that has been opened up for it.
--
-- The difference from an ordinary vanishing is that this one is PAID FOR ON THE WAY OUT. Invisibility
-- in this game is a window that closes on a clock; you hide, you reposition, the clock runs down, and
-- what you bought was distance. Stillshade buys distance too, and then charges the exit price to the
-- enemy: whoever the rogue steps out onto is left Exposed, which every piercing thing the party owns
-- can read.
--
-- Which makes it a SETUP the whole company shares rather than an escape one character takes. The rogue
-- vanishes on turn one; on turn two they open a foe and the hunter's arrows, the knight's spear and
-- the alchemist's lancet all bite deeper for the rest of the exchange. Greed's shelf is guile and
-- conditional multipliers (docs/classes.md), and this is the condition being manufactured.
--
-- It does NOT survive the light. A Witchlight flare makes an unhidden target of anything standing in
-- it whatever it is wearing (Status.untargetable), so the counterplay exists, costs a consumable slot,
-- and belongs to the enemy rather than to the clock.
--
-- ADJACENCY: a `dagger` beside it. Stepping out of the shade is a knife's motion and nothing else's --
-- and it puts the spell in the rogue's most crowded cell, competing with everything that already wants
-- to sit next to the blade.
return {
    name = "Stillshade",
    description = "Vanishes until it strikes; whatever it strikes is left open to piercing hits.",
    flavor = "Not gone. Standing very still, in a place the eye has agreed to skip.",
    sprite = "assets/items/ability_stillshade.png",
    type = "ability",
    tags = { "dark" },
    class = "rogue",
    price = 320,
    repRank = 3,
    -- The exit price rides on the item, because a trait only ever attaches from a grid item (see
    -- Trait.attach). The spell leaves a promise on its caster; this is the thing that collects it a
    -- turn later, when the rogue finally steps out.
    traits = { "trait_stillshade" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        cost = { { stat = "mana", amount = 6 }, { stat = "stamina", amount = 6 } },
        support = true,
        requiresAdjacent = { tag = "dagger" },
        effect = function(fx)
            -- The vanishing itself is the existing status, unchanged: one concealment mechanic in the
            -- game, one set of rules for what breaks it and what sees through it. This spell is not a
            -- second kind of hiding, it is the ordinary kind bought with a different exit.
            fx.applyStatus(fx.user, "status_invisible", { duration = 12 + fx.level })
            -- The exit price is stamped onto the rogue as a MARK the strike will spend, rather than
            -- applied to a victim who has not been chosen yet -- see data/traits/trait_stillshade.lua,
            -- which is what actually opens the body when the concealment breaks.
            fx.applyStatus(fx.user, "status_mark", { duration = 12 + fx.level })
        end,
    },
}
