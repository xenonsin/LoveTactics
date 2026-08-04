-- The Assayer's Eye: a smear of reagent across the lens, and a foe's satchel gives up its contents --
-- every blade, charm and draught it carries, laid open for the rest of the fight. It takes nothing
-- (Greed wants the thing; Envy would rather you had neither the thing nor the not-knowing) and deals no
-- damage -- the payload is knowledge. Once a foe is assayed, hover it (on the board or on the timeline)
-- to read each item it carries in the same tooltip your own grid gets: plan around the mace before it
-- swings and the potion before it's drunk.
--
-- An assay is the alchemist's test of what a thing is truly made of; turned on a person, it reads their
-- pockets. Envy's verb -- to want the coveting exact.
return {
    name = "Assayer's Eye",
    description = "Lays a foe's whole kit open this battle: hover the foe to read every item it carries.",
    flavor = "An assay tells you what a thing is truly made of. Envy asks the same of a man's pockets.",
    sprite = "assets/items/ability_assayers_eye.png",
    type = "ability",
    tags = { "arcane" },
    class = "alchemist",
    price = 180,
    unlockQuests = 3,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            fx.reveal(fx.target)
        end,
    },
}
