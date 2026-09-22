-- THE LAST SOUNDER: the dead get up, and they get up as boars.
--
-- The Unseeing's own second half, taken off him (data/items/ability/ability_the_taking.lua). Sweep the
-- corpses on a patch of floor and each one stands back up on your side as a Wild Boar -- whatever it
-- was before -- AND WHAT GETS UP IS CURSED. Each one carries the Wake (utility_the_wake), so the ground
-- it crosses is ground nothing can be healed on.
--
-- THAT IS THE ITEM, and without it this was three extra bodies and not much else. Boars are not the
-- payload; the FLOOR is. Three risen boars walking a corridor leave three trails of curse behind them,
-- and what you have bought is not damage but a room the enemy's healer cannot work in -- laid by bodies
-- that are moving anyway, on ground you chose by deciding where the fight happened.
--
-- THE CURSE DOES NOT CARE WHOSE BOAR IT IS. A hazard is side-agnostic here as everywhere, so a raise in
-- the middle of your own line salts the tiles your priest was standing on. That is the decision the item
-- is, and it is why it is aimed rather than centred on the caster: you are choosing which end of the
-- room stops being healable.
--
-- IT IS NOT RAISE DEAD, AND THE DIFFERENCE IS THE WHOLE ITEM. ability_raise_dead makes zombies: slow
-- bodies that walk at the nearest thing and hit it, which is a second front. This makes boars, and a
-- boar is not a second front -- it is a lane (ability_gore), committed a turn early and painted on the
-- board. So a field you have just won a fight on becomes three published threats at once, all of them
-- pointing wherever the corpses happened to fall. The necromancer's version asks "how many bodies do I
-- have"; this one asks "where did they die", which is a question about the fight you just had.
--
-- THE CHASE, AND PRICED AS ONE. It is the deepest thing the Unseeing hands over and it should be: the
-- turn it is worth taking is the turn there are three or four bodies down in one place, which is late
-- in a long fight and never in a short one. An item that is dead weight for the first half of every
-- fight has to be worth the wait when it lands.
--
-- CORPSES ONLY, deliberately. Combat.corpseAt refuses a body still inside its revive window
-- (INCAPACITATED is not a corpse) and refuses any tile a living body stands on, so this cannot reach
-- your own fallen and cannot be aimed at somebody who is merely dying. The lord's version takes the
-- dying as well; his is a boss's rule and this is a player's, and the gap between them is the mercy.
--
-- They rot away on a timer, on Raise Dead's rule. A raised body leaves no corpse of its own
-- (Combat.raiseZombie spends it), so a field cannot be worked twice and this never loops.
return {
    name = "The Last Sounder",
    description = "Every corpse nearby stands back up as a cursed wild boar on your side.",
    flavor = "The Warren's word for a group of them. Nobody asked what the last one was counting.",
    -- Raised to 9.0 -> 12.0 when the risen started carrying the Wake: three bodies is a second front,
    -- three bodies laying ground nothing mends on is a different item. Still authored rather than
    -- derived, for the reason below -- the instrument can see neither half.
    sprite = "assets/items/utility_the_last_sounder.png",
    type = "utility",
    tags = { "horn", "summon", "dark" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS: the house that reads a corpse as a resource.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry it.
    class = "necromancer",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch, as utility_unpaid_tithe
    -- uses it). The instrument reads net stat swing and replayed damage; a raise produces neither, so
    -- left underived this filed at **-14.6** -- the lowest score in a catalogue of 354 -- and
    -- tools/drop_tier.lua duly made the chase the shallowest thing in the game. The figure below is
    -- what three or four boars on a bloodied field are worth, judged against the horn's one -- and it
    -- has to land ABOVE the horn or the list inverts: depth is rarity here, so the chase being graded
    -- under the common piece would make the common piece the rare one.
    grade = 12.00,
    unlockLevel = 15,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        speed = 6,
        cost = { stat = "stamina", amount = 12 },
        support = true, -- raising your own is a kindness: preview green
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            -- Gathered before anything is raised: an arrival puts a LIVING body on the tile, and
            -- Combat.corpseAt refuses a tile someone is standing on -- so sweeping and raising in one
            -- pass would have each boar hide the next corpse along.
            local dead = {}
            for _, c in ipairs(fx.aoeCells()) do
                local corpse = fx.corpseAt(c.x, c.y)
                if corpse then dead[#dead + 1] = corpse end
            end
            for _, corpse in ipairs(dead) do
                local risen = fx.raise(corpse, "character_boar", { duration = 24 })
                -- THE WAKE, GRANTED RATHER THAN BUILT IN. `trail` is read off whatever is in the grid
                -- at the moment a body moves (Combat.layTrail, from Combat.enterTile), so handing the
                -- item over after the raise is enough and nothing needs a second boar blueprint.
                --
                -- Granted rather than passed as `opts.items`, which REPLACES a summon's whole inventory
                -- (models/summon.lua) -- that road means restating the boar's kit here, where it would
                -- silently rot the day character_boar.lua changes. fx.grantItem stamps it `ephemeral`,
                -- so it is real for this fight and stripped on the way out: a risen boar is not a Wake
                -- farm, and in any case only ENEMY grids feed the drop pool (models/spoils.lua).
                if risen then fx.grantItem(risen, "utility_the_wake") end
            end
        end,
    },
}
