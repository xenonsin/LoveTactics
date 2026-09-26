-- THE AMBUSHER'S HOOD: the Bugbear's drop (approved as pitched, 2026-09-26, "The Goblins of Wrath"). You start
-- each fight Invisible until you act -- an opening boon (`openingBoon`, the Duelist's Spur's shape), and
-- Invisible ends at its bearer's next turn on its own. A poacher's piece: the wait in cover before the first blow.
return {
    name = "Ambusher's Hood",
    description = "Start each fight Invisible until you act.",
    flavor = "It smells of every place it has ever waited, which is most of the flows.",
    sprite = "assets/items/utility_ambushers_hood.png",
    type = "utility",
    tags = { "trinket" },
    class = "poacher",
    unlockLevel = 8,
    unstocked = true,
    openingBoon = { id = "status_invisible" },
}
