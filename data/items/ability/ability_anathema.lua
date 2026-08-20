-- Anathema: the priest names a foe accursed, and the naming is the whole working. It applies
-- Vulnerable: Holy (data/status/status_vulnerable_holy.lua) -- the target takes +8 from every holy hit
-- for a time -- and does no damage of its own. Setup, said in a censer's voice.
--
-- On the priest shelf because holy is the Cathedral's own word (docs/classes.md), and because branding
-- a target for the party's consecrated weapons -- the censers, the Demon-Bane, the smites -- is lust's
-- kind of answer: it holds a body open for others rather than closing the kill itself. Reads as vicious
-- against demons and the church's blooded sleepers. The holy half of the Vulnerable/Forsaken pair; see
-- docs/vulnerability.md.
return {
    name = "Anathema",
    description = "Inflicts Vulnerable: Holy.",
    flavor = "The verdict is somebody else's to carry out. The naming is the priest's.",
    sprite = "assets/items/ability_anathema.png",
    type = "ability",
    tags = { "utility", "holy" },
    class = "priest",
    discipline = "inquisitor", -- rogue x priest; Judgment -- the naming that holds a body open for the execute
    price = 210,
    unlockQuests = 1,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 6 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_vulnerable_holy")
        end,
    },
}
