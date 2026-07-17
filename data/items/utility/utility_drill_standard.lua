-- The item form of Formation Fighter: a drill standard whose bearer stands stronger the more allies
-- flank it -- defense and magic defense for each ally adjacent at battle's start. A knight-class
-- banner, sold at the Bastion; it rewards a tight, disciplined line.
return {
    name = "Drill Standard",
    description = "You stand tougher for each ally flanking you at the opening bell.",
    flavor = "The Bastion drills the line before it drills the sword. A banner is an argument for standing close.",
    sprite = "assets/items/drill_standard.png",
    type = "utility",
    tags = { "banner" },
    class = "knight",
    price = 200,
    repRank = 2,
    traits = { "trait_formation_fighter" },
}
