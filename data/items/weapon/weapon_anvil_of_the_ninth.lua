-- A hammer, so it stuns (docs/weapons.md) -- and its extra is that the wielder is stopped too. The blow
-- stuns the target and leaves the swinger Halted (status_halted): unable to use any ability at all until
-- it lifts, though movement and reflexes are untouched.
--
-- Quest-only: `class` with no `price`.
--
-- The family already sells a mutual price -- you buy the stun with your own tempo -- and this states it
-- literally instead of as arithmetic. What you get for the honesty is a stun far beyond what the shelf
-- otherwise offers, on a swing that also hits harder than an iron hammer.
--
-- Two things make it playable rather than merely costly, and both are properties of Halted specifically
-- (data/status/status_halted.lua): it does not stop the wielder MOVING, and it does not stop the wielder
-- ANSWERING. So an Anvil fighter swings once, is silenced for a beat, and spends that beat walking into
-- position and parrying whatever comes -- which is a real turn, just not an offensive one. Pair it with
-- a sword's reflex or a shield's brace and the dead beat is where the rest of the loadout lives.
--
-- The obvious way to lose with it: swinging it while the party needs a second attack immediately.
return {
    name = "Anvil of the Ninth",
    description = "A crushing stun -- and the swing leaves you Halted, unable to use any ability until it lifts.",
    flavor = "The Ninth were not required to be clever. They were required to be there afterwards, and mostly they were.",
    sprite = "assets/items/anvil_of_the_ninth.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        cost = { stat = "stamina", amount = 13 },
        -- Above an iron hammer's, which is the compensation for the self-inflicted half below.
        damage = { 16, 17, 19, 20, 22, 23, 25, 26, 28, 29, 31 },
        effect = function(fx)
            -- Longer than an ordinary stun, and it rides the blow for the family's usual reason.
            fx.damage(fx.target, { inflicts = { id = "status_stun", magnitude = 9 } })
            -- ...and the price, applied last so a swing that somehow failed to resolve has not already
            -- billed the wielder for it.
            fx.applyStatus(fx.user, "status_halted")
        end,
    },
}
