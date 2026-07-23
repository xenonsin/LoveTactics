-- The Lodge's horn: swaps the holder's Wait into Perform (Combat.waitBehavior / Combat.perform).
-- Instead of delaying, the bearer sounds the next air in a fixed three-part cycle, and it lands on the
-- bearer and every ally within earshot.
--
-- IT IS A CHARM, NOT A WEAPON FAMILY, and that is a decision rather than a shortcut. `waitBehavior` is
-- an item-level field that Combat.waitBehavior finds on ANY grid item -- which is how the Focus Stone and
-- the Overwatch Scope already swap a Wait without being weapons (data/items/utility/utility_focus_stone.lua,
-- utility_overwatch_scope.lua). An `instrument` archetype would have bought nothing those two do not
-- already prove: a new family owes a base weapon, a strike, a row in docs/weapons.md and a case in the
-- weapon sweep, and every one of those would exist to describe a thing whose entire mechanic is that you
-- are NOT swinging it. A horn is something a hunter carries, so it goes where the other carried things go.
--
-- WHY IT IS GLUTTONY'S. The shelf's line is "setup, then payoff" (docs/classes.md), and this is the
-- longest setup on it: three turns not fighting to walk the whole cycle once. The sin is in the shape of
-- the cycle rather than its size -- the horn never lets you take just the air you wanted. You want the
-- Feast; the Feast comes after the Chase and the Scent, every time, in that order, and the only way to
-- have it is to sit through the whole meal again. A Lodge that never stops being hungry would build
-- exactly this and call it tradition.
--
-- The airs are three statuses that already exist, deliberately: a horn is not a new vocabulary, it is a
-- slower and more generous way to spend one the party already reads.
return {
    name = "Hunting Horn",
    description = "Replaces Wait with Perform: sound the next of three airs for yourself and every ally in earshot.",
    flavor = "Three calls, always in that order. The Lodge has forgotten it was ever a choice.",
    sprite = "assets/items/hunting_horn.png",
    type = "utility",
    tags = { "horn" },
    class = "hunter",
    price = 420,
    repRank = 3,
    waitBehavior = {
        kind = "perform",
        -- Steeper than a Focus and matching the Overwatch Scope's: a whole turn spent playing, never a
        -- move-and-play. `speed` deliberately does not scale with the forge (models/item.lua).
        speed = 12,
        earshot = 2, -- does not scale: an upgrade buys a longer song, never a wider one
        -- Both DO scale with the forge: a better horn holds its air longer and pours more into the one
        -- air that carries a magnitude. See WAIT_BEHAVIOR_MAGNITUDES in models/item.lua.
        duration = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
        amount = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 },
        -- The cycle, and the order is the item. Tempo, then teeth, then the mending -- the Lodge's own
        -- account of a hunt, which is why the payoff is last and you have to earn your way back to it.
        songs = {
            -- Halves what every ability and every step costs the timeline. The strongest of the three,
            -- and first on purpose: it is the one you get for free the moment you pick the horn up.
            { name = "The Chase", status = "status_hasted" },
            -- Damage and Defense both (statBonus, tuned by the status's own def -- so no `scales`).
            { name = "The Scent", status = "status_inspiration" },
            -- The only air that reads the horn's `amount`, as health mended per turn.
            { name = "The Feast", status = "status_regen", scales = true },
        },
    },
}
