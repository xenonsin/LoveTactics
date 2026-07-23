-- A censer, so the smoke is the weapon (docs/weapons.md). Its cloud is hazard_darkness -- unnatural dark
-- that nothing can see a line across, though walking through it is untouched. Its strike is `dark`, the
-- only such tag on the Cathedral's shelf.
--
-- Quest-only: `class` with no `price`.
--
-- A walking wall against every ranged weapon in the game. Sight is what a bow, a longbow and most of the
-- Arcanum's list all require (`requiresSight`), and darkness is the one thing that stops it -- so a
-- priest carrying this is a mobile piece of cover that the enemy cannot shoot away, walk around quickly,
-- or dispel off a body, because it is not on a body.
--
-- The reason it is a censer and not a spell is the movement. A static darkness is something the enemy
-- archer simply steps to one side of. This one follows the party across the field, so the advance itself
-- is covered -- which is the only answer in the catalog to being out-ranged for a whole battle.
--
-- Unsided, and severely: your own archers and your own mage cannot see out of it either. A company
-- carrying this and a longbow is a company arguing with itself. It belongs with steel.
--
-- The `dark` tag on the strike is the deliberate discomfort. It is the Cathedral's item and it is not a
-- holy one, which is the same argument the Censer of Ashes makes about what lust's shelf is willing to
-- pick up (docs/weapons.md: the object never changes, only the voice it is swung in).
return {
    name = "Censer of the Hollow Dark",
    description = "Wreathes you in unnatural dark: nothing can see a line across it, in either direction.",
    flavor = "The censer-bearer is told not to look into it. The Cathedral has never explained what the instruction is protecting.",
    sprite = "assets/items/censer_hollow_dark.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "dark", "melee" },
    class = "priest",
    incense = {
        hazard = "hazard_darkness",
        radius = 1,
        amount = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target) -- carries `dark`, which some flesh resists and some does not
        end,
    },
}
