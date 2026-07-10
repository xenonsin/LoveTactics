-- The item form of Formation Fighter: a drill standard whose bearer stands stronger the more allies
-- flank it -- defense and magic defense for each ally adjacent at battle's start. A knight-class
-- banner, sold at the Bastion; it rewards a tight, disciplined line.
return {
    name = "Drill Standard",
    description = "A company banner. You stand tougher the more allies flank you at the opening bell.",
    sprite = "assets/items/drill_standard.png",
    type = "utility",
    tags = { "banner" },
    class = "knight",
    price = 200,
    repRank = 2,
    traits = { "formation_fighter" },
}
