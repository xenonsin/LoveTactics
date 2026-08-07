-- Forsake: a curse that picks loose a target's ward against shadow, leaving it Vulnerable: Dark
-- (data/status/status_vulnerable_dark.lua) -- +8 from every dark hit for a time. No damage of its own:
-- it is the opener, and the grief pours in behind it.
--
-- On the mage shelf because `dark` is the mage's element -- the Necromancer's own word (docs/classes.md)
-- -- and because remaking what a body is proof against is pride's kind of overreach. The dark twin of
-- Anathema, completing the pair so both sacred schools have a matching opener. See docs/vulnerability.md.
return {
    name = "Forsake",
    description = "Inflicts Vulnerable: Dark.",
    flavor = "It does not curse them with harm. It curses them with everything that comes for them after.",
    sprite = "assets/items/ability_forsake.png",
    type = "ability",
    tags = { "utility", "dark" },
    class = "mage",
    price = 200,
    unlockQuests = 2,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 6 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_vulnerable_dark")
        end,
    },
}
