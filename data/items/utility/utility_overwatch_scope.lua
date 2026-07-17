-- Overwatch Scope: swaps the holder's Wait action into Overwatch (Combat.waitBehavior / Combat.overwatch).
-- Instead of delaying, the hunter holds the line: any foe that WALKS into the range of its default
-- weapon is shot automatically, once per step it spends in range, until the hunter's stamina runs dry.
-- Setting the stance is expensive on the timeline (a whole turn spent watching, no move-and-shoot), and
-- each reaction shot costs `stamina`. The reaction itself lives in Combat.triggerOverwatch (fired from
-- Combat.stepMove); this item only declares the swap.
return {
    name = "Overwatch Scope",
    description = "Replaces Wait with Overwatch: auto-fire on any foe that walks into range, for stamina.",
    flavor = "Holding the line is not the same as doing nothing, though from the field it looks identical.",
    sprite = "assets/items/overwatch_scope.png",
    type = "utility",
    tags = { "scope" },
    class = "hunter",
    price = 280,
    repRank = 3,
    waitBehavior = { kind = "overwatch", speed = 12, stamina = 6 },
}
