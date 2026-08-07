-- Minor Shock: the apprentice's first working, and the one the prologue teaches.
--
-- IT IS THE SPELL JOLT USED TO BE, lifted out whole so that Jolt could stop being two things at once.
-- Jolt was the Arcanum's opening-shelf spell AND the village lesson's teaching cast, which meant its
-- numbers answered to the choreography rather than to the shelf: the prologue's closing beat is tuned
-- to the exact weight of one cast (data/characters/character_demon_grunt.lua's health is "the SUM of
-- five authored blows", and this is one of them), so Jolt could never be priced as what it actually is
-- -- a stun on a bolt, which is a large thing to carry. The moment the shelf ladder was read off power
-- rather than off price it climbed, and the lesson broke.
--
-- So the lesson gets its own spell and the shelf gets its own. Every number here is Jolt's as it stood
-- when the prologue was authored around it -- damage, stun, speed, cost, range -- because the
-- choreography is the specification. Change one and the village lesson stops landing; that is not a
-- balance dial, it is a script.
--
-- WHAT IT SELLS is tempo, not damage. It does almost nothing to a body; what it buys is ticks off the
-- target's next turn, and an ability that hands you the initiative should cost some of your own to
-- throw (hence `speed`, slower than a sword swing). That is also what makes the prologue's ending
-- work: the caster comes back around just BEHIND the ally the stun bought a turn for, so the ally
-- swings first and the player still lands the last blow. See data/tutorials/village.lua.
local Curve = require("models.curve")

return {
    name = "Minor Shock",
    description = "Deals light damage and inflicts Stun.",
    flavor = "The first thing an apprentice is taught, and the first thing they overestimate.",
    sprite = "assets/items/ability_jolt.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "mage",
    price = 80,
    unlockQuests = 0,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line: terrain cover blocks it
        speed = 4,            -- slower than a sword swing: the price of the tempo it sells
        cost = { stat = "mana", amount = 5 },
        damage = Curve.ramp(6, 16),
        -- The delay, on its own axis and its own curve -- forging this should buy TIME, not a better
        -- hit.
        --
        -- SIX, not ten. Ten ticks is two whole turns at Status.TICKS_PER_TURN, which is an enormous
        -- thing for the first spell a player is handed -- double what status_stun itself is worth, off
        -- an ability that costs five mana. Six is one turn taken and a little of the next, which is
        -- what the village lesson actually needs: the grunt's card has to slide below Rowan's and the
        -- avatar's, and the pace list (data/tutorials/village.lua) is what states that order -- the
        -- stun's job is to make it TRUE on the clock, not to force it. Verified against the lesson
        -- rather than assumed: tests/tutorial_spec.lua plays the whole fight and reads the order back.
        stun = Curve.ramp(6, 16),
        effect = function(fx)
            -- power + the caster's MagicDamage, minus MagicDefense. The stun rides the blow so it
            -- lands before the target can react to it, and carries its own authored magnitude.
            fx.damage(fx.target, {
                inflicts = { id = "status_stun", magnitude = fx.item.activeAbility.stun },
            })
        end,
    },
}
