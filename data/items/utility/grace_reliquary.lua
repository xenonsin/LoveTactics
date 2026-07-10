-- The item form of the Priest's Sanctified Presence: a reliquary whose bearer sanctifies the ground,
-- mending adjacent allies (and themselves) a little each tick. Slot it and any character becomes a
-- slow, positional font of life. A priest-class relic, sold at the Cathedral.
return {
    name = "Reliquary of Grace",
    description = "Holy relics in a gilt case. Allies beside you mend a little each moment.",
    sprite = "assets/items/grace_reliquary.png",
    type = "utility",
    tags = { "relic", "holy" },
    class = "priest",
    price = 280,
    repRank = 3,
    traits = { "sanctified_presence" },
}
