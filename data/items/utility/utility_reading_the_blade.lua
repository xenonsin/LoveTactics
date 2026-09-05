-- Reading the Blade: the build half of the Duelist (fighter x rogue), and the file where the duel
-- stance is finally WRITTEN DOWN. En Garde has always escalated on a held target, but it kept the count
-- inside its own effect -- so the shelf's defining idea only existed while you were pressing one
-- particular button. This charm makes it a fact about the fighter: every blow that lands on the body you
-- hit last banks a point of Tempo, thrown however you like.
--
-- And it EMPTIES when you look away (`resetOn = "targetSwitch"`, forfeited by Combat.dealDamage). That
-- is the discipline's bargain stated as a cost rather than as flavour: the tempo belongs to the duel,
-- not to you, and a Duelist who spreads their attention across the line arrives at the payoff with
-- nothing. It is the exact inverse of the Skirmisher's Harrying Pattern, which pays for never hitting
-- the same body twice -- two disciplines, opposite answers to one question.
--
-- A charm rather than an ability, because it is a way of fighting rather than a thing you do
-- (docs/classes.md, traits-attach-via-items). Coup Droit spends the pool and the Main-Gauche deepens it.
--
-- IT USED TO DECLARE THE POOL AND NOTHING ELSE, and this header said so approvingly. That was half a
-- mechanic sold as a whole item: a 380g charm banking Tempo that only a second purchase could drain, so
-- bought on its own it did nothing at all. docs/classes.md forbids exactly that shape -- "what no item
-- may be is another item's on-switch" -- and the rule had only ever been enforced against SPENDERS, so
-- the three self-sufficient spenders were paired with three bankers that were nobody's. Watching the
-- Shoulder is the dividend: it READS Tempo without spending it, one damage a point, so the read pays
-- while it is held and Coup Droit is still the only thing that cashes it in.
return {
    name = "Reading the Blade",
    description = "Increase damage by 1 per Tempo held. Blows on the foe you struck last bank Tempo; strike anyone else and it is gone.",
    flavor = "Four exchanges in, she was not watching the sword any more. She was watching his shoulder.",
    sprite = "assets/items/utility_reading_the_blade.png",
    type = "utility",
    tags = { "charm" },
    class = "duelist",
    unlockQuests = 6,
    dropTier = 5,
    traits = { "trait_watching_the_shoulder" },
    charge = { key = "tempo", from = { "repeatStrike" }, max = 5, resetOn = "targetSwitch" },
    -- it converts tempo into Power, so the floor is the tempo itself
    bonus = { speed = 1 },
}
