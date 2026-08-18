-- The Assayer's Eye: a smear of reagent across the lens, and a foe's satchel gives up its contents --
-- every blade, charm and draught it carries, laid open for the rest of the fight. It takes nothing
-- (Greed wants the thing; Envy would rather you had neither the thing nor the not-knowing) and deals no
-- damage -- the payload is knowledge. Once a foe is assayed, ASK for its kit -- press K over it, or
-- click its turn-order card -- and its 3x3 grid opens beside it, each slot reading into the same
-- tooltip your own grid gets: plan around the mace before it swings and the potion before it's drunk.
-- The card is pinned rather than hovered, so knowing what a foe carries never costs you the sight of
-- the board you are about to aim at.
--
-- An assay is the alchemist's test of what a thing is truly made of; turned on a person, it reads their
-- pockets. Envy's verb -- to want the coveting exact.
return {
    name = "Assayer's Eye",
    description = "Lays a foe's whole kit open this battle: press K over the foe to read every item it carries.",
    flavor = "An assay tells you what a thing is truly made of. Envy asks the same of a man's pockets.",
    sprite = "assets/items/ability_assayers_eye.png",
    type = "ability",
    tags = { "arcane" },
    class = "alchemist",
    price = 80,
    unlockQuests = 0,
    activeAbility = {
        target = "enemy",
        -- Aimed at a foe, but it is not a blow: `harmless` is the third valence beside support and
        -- offense (Combat.isHarmlessAbility). It buys the whole reading -- a steel band instead of a
        -- red one, a shimmer instead of the swing, no lunge, and an enemy AI that never plans it --
        -- because a lens laid over somebody's satchel should not read as a swing that missed.
        harmless = true,
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            fx.reveal(fx.target)
        end,
    },
}
