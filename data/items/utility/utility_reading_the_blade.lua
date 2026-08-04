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
-- (docs/classes.md, traits-attach-via-items). It declares the pool and nothing else; Coup Droit spends
-- it and the Main-Gauche deepens it.
return {
    name = "Reading the Blade",
    description = "Each blow on the foe you struck last banks Tempo. Strike anyone else and it is gone.",
    flavor = "Four exchanges in, she was not watching the sword any more. She was watching his shoulder.",
    sprite = "assets/items/utility_reading_the_blade.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "duelist",
    price = 380,
    unlockQuests = 8,
    charge = { key = "tempo", from = { "repeatStrike" }, max = 5, resetOn = "targetSwitch" },
}
