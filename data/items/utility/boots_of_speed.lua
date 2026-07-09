-- A flat +1 to movement, folded into the wearer at battle setup exactly like a piece of armor's
-- bonus (Combat.applyPassives -> unit.bonus -> flatStat -> Combat.moveBudget), so it widens the
-- blue reachable set with no code of its own.
return {
    name = "Boots of Speed",
    description = "Light on the feet: move one extra space each turn.",
    sprite = "assets/items/boots_of_speed.png",
    type = "utility",
    tags = { "boots" },
    bonus = { movement = 1 },
}
