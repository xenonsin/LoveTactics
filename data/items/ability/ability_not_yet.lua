-- Not Yet: for a few turns the target cannot die. Whatever lands on them, they are left standing at
-- the last point of health, and the priest has bought the party a window to fix the situation in.
--
-- Built on `preventsDeath`, the flag Fury's berserk window already uses -- Combat.dealFlatDamage floors
-- the survivor at 1 rather than dropping them. Nothing new was needed in the model; what is new is
-- selling it as a CAST, on somebody else, at range.
--
-- Which makes it a different item from the traits that do something similar. Last Stand and Survivor's
-- Reflex are things a character wears and cannot choose when to use; this is a decision made on a
-- specific turn about a specific ally, which means it is only ever as good as the priest's read of the
-- board. Cast it a turn early and it lapses before the blow. Cast it a turn late and there is nobody
-- to cast it on.
--
-- IT DOES NOT HEAL. The target spends the whole window at whatever health the last hit left them, which
-- is usually one -- so this is not a rescue, it is a DELAY of a death, and the party has to do
-- something with the delay. Paired with Seal the Hour it is the Cathedral's whole thesis: the priest
-- does not undo what happened, they decide when it counts.
--
-- Short, deliberately. A long one would simply be an enemy turn tax; at two turns it is a window
-- somebody has to actually use.
--
-- ADJACENCY: a `staff` beside it rather than the censer. The Cathedral's censers do the ceremonial
-- work -- the seals and the wards -- and this is field triage, done leaning on something. It is also
-- the one gate on this shelf a Monk can meet.
return {
    name = "Not Yet",
    description = "For a short while the target cannot be killed, and is left standing at a sliver.",
    flavor = "Two words, said quickly, over somebody who was not going to get a longer sentence.",
    sprite = "assets/items/ability_not_yet.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "priest",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "ally",
        range = 5,
        speed = 2, -- fast: the whole item is being able to cast it on the turn it is needed
        cost = { stat = "mana", amount = 12 },
        support = true,
        requiresAdjacent = { tag = "staff" },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_not_yet", { duration = 10 + fx.level })
        end,
    },
}
