-- Main-Gauche: the rogue half of the Duelist (fighter x rogue). A left-hand dagger that does the one
-- thing a dagger is not supposed to do -- it PARRIES -- and banks the duel's Tempo for every blow it
-- turns aside.
--
-- The family contract still holds: it is fast and it opens a wound, because that is what makes a dagger
-- a dagger (docs/weapons.md). What it adds is the parry, which properly belongs to the sword -- and the
-- borrow is the whole point rather than a slip, so it is said out loud here the way weapons.md expects.
-- A main-gauche is the off-hand blade of a duellist: its historical job was never to kill, it was to
-- catch the other blade while the right hand did the killing. A dagger that answers is exactly the
-- object, and the Duelist is the one discipline entitled to it.
--
-- It is also how a Duelist banks Tempo on the DEFENSIVE beat. Reading the Blade fills the pool by
-- pressing the same target; this fills it by surviving them, off the `answered` tally that every reflex
-- in the game already feeds (models/trait.lua's tallyAnswer). A duel is two people taking turns, and
-- the pool now fills on both of them.
--
-- Note it does NOT carry `resetOn`: the merge in Combat.chargeDef takes the union of `from` and the
-- deeper `max`, and a reset condition declared by the other item still governs the pool. Switching
-- targets forfeits Tempo whether it was banked by pressing or by parrying -- one pool, one rule.
return {
    name = "Main-Gauche",
    description = "A left-hand dagger that parries. Bleeds on the hit, and banks Tempo for every blow it turns aside.",
    flavor = "The right hand is the argument. This one is the punctuation.",
    sprite = "assets/items/weapon_main_gauche.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    discipline = "duelist",
    price = 340,
    repRank = 3,
    traits = { "trait_parry" },
    charge = { key = "tempo", from = { "answered" }, max = 5 },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- the family's own tempo: quick back around, which is what makes the parry affordable
        cost = { stat = "stamina", amount = 5 },
        damage = { 5, 5, 6, 7, 7, 8, 9, 9, 10, 11, 12 },
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_bleed" })
        end,
    },
}
