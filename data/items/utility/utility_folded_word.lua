-- Garan's bound relic (Battlemage). He casts with the blade, not beside it.
--
-- THE SHELF ALREADY CARRIES ELEMENT INTO STEEL one swing at a time -- Resonant Grip puts the last
-- cast's element on his strikes, Arcane Cleave is a melee blow with a spell in it. This folds the whole
-- working in and keeps it there for three swings, so the fighter half stops being a way to pass the
-- turns between spells and becomes where the spells land.
--
-- BATTLE CASTING IS THE ENGINE UNDERNEATH IT: a non-magical blow hands mana back, so the three swings
-- pay for the next cast that reloads this. That loop is the build, and it is why the gate is `cast`
-- rather than a census -- what has to be true is that he has been casting, and three casts is three
-- turns of it.
return {
    name = "The Folded Word",
    description = "Your next three blows each carry the element of your last spell.",
    flavor = "He stopped saying them out loud some years ago. They go in the swing now.",
    sprite = "assets/items/sig_folded_word.png",
    type = "utility",
    tags = { "signature", "arcane" },
    class = "mage",
    discipline = "battlemage",
    bound = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        description = "Stores three blows carrying your last cast's element.",
        unlock = { event = "cast", count = 3, text = "Cast 3 times" },
        effect = function(fx)
            -- Three stored strikes, not one: Empowered is spent on the first blow that draws blood, so
            -- the magnitude is what makes it a fold rather than a single charged swing. The element
            -- itself rides on Resonant Grip's own rule when he carries it -- this is the force behind it.
            fx.applyStatus(fx.user, "status_empowered", { magnitude = 8 })
            fx.applyStatus(fx.user, "status_arcane_cultivation")
        end,
    },
}
