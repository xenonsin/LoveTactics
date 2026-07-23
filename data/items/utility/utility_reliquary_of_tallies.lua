-- The Reliquary of Tallies: a small iron box that fills up as the battle goes badly for somebody. It
-- takes a charge from every death on the field, and spends its charges either way -- mending an ally,
-- or wounding a foe.
--
-- AN ECONOMY RATHER THAN AN EFFECT, and the shape of it is the item. It arrives EMPTY: on turn one it
-- does nothing at all, and a party that opens with it has wasted a slot. It fills from `allyDown` and
-- from the field's own dead, so by the fourth turn of a real fight it is worth more than most things
-- on this shelf -- and in a fight that ends quickly it never pays out at all.
--
-- Which makes it the catalog's one explicitly LATE item, and a genuine argument against itself: the
-- fights it is best in are the fights the party is closest to losing.
--
-- Two mouths, one purse. The charges mend or they wound, and the choice is made per cast rather than
-- per build -- so the same box is a heal in the first half of a battle and a finisher in the second.
-- Nothing else here lets a single slot be either.
--
-- The tally is read off Combat.tallyCount, which the model already banks on every unit for exactly
-- this kind of thing (`allyDown` is counted for every surviving ally when a real combatant falls --
-- see killUnit). No new bookkeeping: the box is reading a number the battle was already keeping.
return {
    name = "The Reliquary of Tallies",
    description = "Fills with every comrade lost; spend it to mend an ally or wound a foe.",
    flavor = "The Cathedral keeps one in every chapter house. They are always, always full.",
    sprite = "assets/items/utility_reliquary_of_tallies.png",
    type = "utility",
    tags = { "holy" },
    class = "priest",
    price = 300,
    repRank = 3,
    activeAbility = {
        -- A tile target so one item can point both ways: at an ally it mends, at a foe it wounds, and
        -- the player decides on the turn rather than at the shop. See Updraft and Seal the Hour, which
        -- are built the same way and for the same reason.
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            local body = fx.unitAt(fx.tx, fx.ty)
            if not body then return end
            -- Every comrade this unit has lost, which is the number the model was already keeping.
            -- Floored at nothing: an empty reliquary is an empty reliquary, and the log says so rather
            -- than quietly doing a small thing.
            local tallies = fx.user.char and require("models.combat").tallyCount(fx.user, "allyDown") or 0
            if tallies <= 0 then
                fx.log("action", "The reliquary is empty. Nothing has been owed yet.", fx.user)
                return
            end
            local weight = tallies * (8 + fx.level)
            if body.side == fx.user.side then
                fx.heal(body, weight)
            else
                fx.damage(body, { amount = weight, tags = { "holy", "magical" } })
            end
        end,
    },
}
