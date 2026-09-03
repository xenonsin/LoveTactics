-- Early Rites: the necromancer says the funeral office over somebody who is still standing, and the
-- world files the paperwork. It lays Interred (data/status/status_interred.lua) on one foe -- every
-- heal aimed at that body lands as a wound of the same size for as long as it holds -- and it does no
-- damage of its own.
--
-- WHAT IT IS ACTUALLY AIMED AT, which is not the target: the enemy healer. Every other answer this
-- game has to a priest on the far side is an interrupt aimed at the priest -- silence them, seal them,
-- kill them first -- and all of them are the same plan at different prices. This one leaves the healer
-- alone and takes their JOB away, then hands it back pointed the wrong way. The wall they were keeping
-- upright is now the fastest thing on the board to kill, and the person killing it is them.
--
-- Deliberately no damage at all, like Toll the Knell beside it on the same shelf. Against a fight with
-- nobody healing anything it is a wasted turn and should be: this is the Arcanum's answer to a specific
-- enemy, not a spell you open with. Read the other side's kit before you buy it.
--
-- WHY IT IS THE NECROMANCER'S. The whole discipline is a clerical error about who counts as dead --
-- Raise Dead conscripts corpses, Toll the Knell schedules a death and the world complies, and this
-- says the words over a living body a little early and lets the world sort out the discrepancy. Note
-- what the party is buying: their own raised dead already live under this rule for free
-- (data/traits/trait_grave_cold.lua), so a mage who fields zombies has already learned the lesson this
-- spell teaches the enemy.
--
-- The forge buys DURATION -- one more beat for the enemy healer to spend badly -- never damage, since
-- there is none to make bigger.
return {
    name = "Early Rites",
    description = "Inflicts Interred on one foe.",
    flavor = "She read the office over him with the ink still wet. He objected. The ledger did not.",
    sprite = "assets/items/ability_early_rites.png",
    type = "ability",
    tags = { "magical", "dark" },
    class = "mage",
    discipline = "necromancer", -- deeper cut of the shelf: buyable only once the necromancer gate is cleared
    price = 245,
    unlockQuests = 2,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 20 },
        effect = function(fx)
            -- 8 ticks at level 0 up to 13 fully honed: a wider window for the other side's healer to
            -- walk into, which is the only thing an upgrade can honestly buy here.
            fx.applyStatus(fx.target, "status_interred", { duration = 8 + math.floor(fx.level / 2) })
        end,
    },
}
