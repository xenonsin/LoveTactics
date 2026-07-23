-- The Gaunt Vigil: the knight drives a hooded iron figure into the floor, and it stands there
-- objecting to sorcery. Anyone who works a spell within three tiles of it is bitten for the privilege
-- (data/characters/character_gaunt_vigil.lua, whose whole kit is data/traits/trait_gaunt_vigil.lua).
--
-- THE STANDING ANSWER TO A CASTER, and the shelf it belongs on is worth explaining. Every other reply
-- to an enemy mage in this game is an INTERRUPT: silence it, stun it, deny it, shatter the channel.
-- All of those are things you must do, on your turn, at the right moment, to the right body -- which
-- means the mage gets to cast whenever you are busy, and you are usually busy.
--
-- This is the knight's version: a thing you put down ONCE, in the place the enemy will have to work
-- from, which charges rent forever without anybody spending another action on it. It does not prevent
-- a single spell. It makes every spell cast there cost blood, which over four turns is a great deal
-- more than one interrupt was ever worth.
--
-- IT DOES NOT PICK SIDES. The vigil taxes your own mage exactly as hard as theirs -- see the trait's
-- own comment on why. Placing it is a statement about which half of the board is going to be the
-- casting half, and if you are wrong about that you have built a wall facing the wrong way.
--
-- One at a time, through the ordinary `activeSummon` claim every summoning item holds
-- (Combat.itemBlockReason refuses the call while the vigil still stands). The knight buys a second one
-- by having the first cut down, which is itself a turn the enemy spent not casting.
--
-- ADJACENCY: a `banner` item beside it -- the same slot the Muster Rift wants. Both are things planted
-- in the ground and left there, and a knight cannot be the company's anchor and its ward at once.
return {
    name = "The Gaunt Vigil",
    description = "Plants an iron figure that bites anyone working a spell near it.",
    flavor = "It has no face and no orders. The Bastion finds both of those reassuring in a sentry.",
    sprite = "assets/items/ability_gaunt_vigil.png",
    type = "ability",
    tags = { "dark" },
    class = "knight",
    price = 420,
    repRank = 4,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 5,
        cost = { stat = "mana", amount = 18 },
        support = true, -- placing an object; it lands nothing on the turn it is set down
        requiresAdjacent = { tag = "banner" },
        effect = function(fx)
            -- `timeless` and control-"none", exactly as a planted banner is: the vigil takes no turns
            -- and holds no slot in the initiative order (Combat.inTimeline). Its whole effect rides on
            -- somebody else's cast, so a turn would be wasted on it.
            fx.summon("character_gaunt_vigil", fx.tx, fx.ty, {
                control = "none", timeless = true, duration = 40 + 4 * fx.level,
            })
        end,
    },
}
