-- The item form of the Priest's Sanctified Presence: a reliquary whose bearer sanctifies the ground,
-- mending adjacent allies (and themselves) a little each tick. Slot it and any character becomes a
-- slow, positional font of life. A priest-class relic, sold at the Cathedral.
return {
    name = "Reliquary of Grace",
    description = "Allies adjacent to you mend a little each tick.",
    flavor = "The Cathedral gilds the case. What is inside it is a great deal less presentable.",
    sprite = "assets/items/grace_reliquary.png",
    type = "utility",
    tags = { "relic", "holy" },
    class = "priest",
    price = 280,
    repRank = 3,
    traits = { "trait_sanctified_presence" },
}
