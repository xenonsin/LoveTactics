-- Quick Brew: the alchemist's first lesson, and the ability a body is handed when it unlocks the
-- Alchemist (the class-unlock design, 2026-10-15, where it is called "Field Brew" -- that id and name
-- already belong to the Herbalist's restorative ground, data/items/ability/ability_field_brew.lua).
--
-- Once a battle, a Healing Potion out of nothing but the caster's turn. It goes where any found potion
-- goes (fx.grantItem -> Combat.grantItem -> Character.addItem): onto a healing-potion stack the caster
-- already carries if it has room, else into the first empty cell. A full grid with no stack to join
-- brews nothing, says so, and the once is spent -- deciding what to carry is the game.
--
-- ONCE A BATTLE is the house idiom for it, a cooldown no fight outlasts (utility_deep_sleep).
return {
    name = "Quick Brew",
    description = "Once per battle, brews a Healing Potion into your grid.",
    flavor = "The Crucible's apprentices learn this one first, mostly so they stop asking for theirs.",
    sprite = "assets/items/ability_quick_brew.png",
    type = "ability",
    tags = { "restorative" },
    class = "alchemist",
    price = 125,
    unlockLevel = 1,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        cooldown = 9999,
        cost = { stat = "mana", amount = 10 },
        description = "Adds a Healing Potion to your stack, or to an empty cell.",
        effect = function(fx)
            fx.grantItem(fx.user, "consumable_healing_potion")
        end,
    },
}
