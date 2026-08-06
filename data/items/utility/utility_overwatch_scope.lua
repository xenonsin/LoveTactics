-- Overwatch Scope: swaps the holder's Wait action into Overwatch (Combat.waitBehavior / Combat.overwatch).
-- Instead of delaying, the hunter holds the line: any foe that WALKS into the range of its default
-- weapon is shot automatically, once per step it spends in range, until the hunter's stamina runs dry.
-- Setting the stance is expensive on the timeline (a whole turn spent watching, no move-and-shoot), and
-- each reaction shot costs `stamina`. The reaction itself lives in Combat.triggerOverwatch (fired from
-- Combat.stepMove); this item only declares the swap.
--
-- AND THE GROUND BESIDE IT IS SLOW (`zone`, Combat.watchTax). That was added after the fact and is a
-- deliberate small buff to an item that was overpriced for what it did: a whole turn bought a
-- CONDITIONAL shot, and the answer was to walk around the firing line, which cost the enemy nothing.
-- Taxing the watcher's own neighbours closes that, and the two halves feed each other -- dear ground
-- means more steps spent in the band, and more steps in the band means more shots.
--
-- 1, against the knight's Held Ground at 2. A sentry watches a WIDE band lightly; a wall watches one
-- square of road and makes it a bog. The two numbers are the whole difference between them.
return {
    name = "Overwatch Scope",
    description = "Replaces Wait with Overwatch: auto-fire on any foe that walks into range, for stamina. Ground beside you costs 1 more.",
    flavor = "Holding the line is not the same as doing nothing, though from the field it looks identical.",
    sprite = "assets/items/overwatch_scope.png",
    type = "utility",
    tags = { "scope" },
    class = "hunter",
    price = 280,
    unlockQuests = 7,
    waitBehavior = { kind = "overwatch", speed = 12, stamina = 6, zone = 1 },
}
