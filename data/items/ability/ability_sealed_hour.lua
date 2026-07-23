-- Seal the Hour: for a little while, nothing that happens to one body actually happens to it. Every
-- wound and every mending is held on a ledger, and the whole account settles as one number when the
-- hour is up (data/status/status_sealed_hour.lua).
--
-- THE BEST THING THE CATHEDRAL SELLS, and the reason is that it buys TIME, which a tactics game can
-- otherwise never buy. The sealed unit cannot fall while three enemies spend their turns on it. Every
-- point they spend is still owed -- so what the priest has actually done is wager that their side can
-- use those three turns better than the enemy can use theirs.
--
-- AND IT HOLDS THE HEALING TOO, which is what stops it being a strictly better barrier and what makes
-- it genuinely difficult to cast well. Sealing an ally at four health is not a rescue. It is a PROMISE
-- to rescue them, and the priest still has to keep it -- get the enemy off them, or pour mending in
-- during the hour so the ledger settles negative and lands whole at the end. This is the only place in
-- the game where healing a full-health unit is not waste.
--
-- Lose the wager and the ledger kills them anyway, on the priest's own clock, which is the cruellest
-- failure state in the catalog and entirely deserved.
--
-- CAST ON AN ENEMY IT IS A DENIAL. The seal does not care whose body it is: an enemy under it cannot be
-- killed either, so sealing the foe your knight is about to finish is a genuine mistake and sealing
-- the foe your knight cannot finish is a genuine play -- it takes their heavy piece out of the killing
-- for two turns and hands them a bill afterwards.
--
-- ADJACENCY: a `censer` beside it. The Cathedral's own instrument, and the one family nobody else may
-- carry (docs/classes.md) -- so this is the most locked-down gate on the shelf, and deliberately: an
-- hour is the Cathedral's to seal.
return {
    name = "Seal the Hour",
    description = "Holds all damage and healing on one body, then settles the whole account at once.",
    flavor = "The Cathedral does not promise that it will not hurt. It promises to say when.",
    sprite = "assets/items/ability_sealed_hour.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "priest",
    price = 520,
    repRank = 4,
    activeAbility = {
        -- A tile target, for the same reason Updraft is one: neither "ally" nor "enemy" describes what
        -- this spell is for, and the player picks which of the two readings above they are buying every
        -- time they cast it.
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 20 },
        support = true,
        requiresAdjacent = { tag = "censer" },
        effect = function(fx)
            local body = fx.unitAt(fx.tx, fx.ty)
            if not body then return end
            -- A forged seal holds LONGER rather than harder, which is the only axis it has: there is
            -- no "more suspended". A longer hour is more turns the party gets to spend, and more debt
            -- accruing if they spend them badly.
            fx.applyStatus(body, "status_sealed_hour", { duration = 12 + fx.level })
        end,
    },
}
