-- A hammer, so it is ponderous and it takes a turn away (docs/weapons.md) -- but it takes it with ice
-- rather than a stun: the blow lands `ice`-tagged and leaves the target Frozen (status_freeze).
--
-- The swap is the weapon, and it is a straight upgrade in one direction and a real loss in another.
-- Freeze shoves the victim down the turn order exactly as a stun does, AND leaves them brittle: +6 taken
-- from every `impact` and `fire` hit while the ice holds. This hammer is `impact`. So the second swing
-- into the same body lands for six more than the first, and the party's fire mage gets the same gift.
--
-- What it gives up is that Freeze is a debuff on the magical school -- a Cure strips it, a warded body
-- resists its duration -- where a stun is simply a fact about the turn order. Against a warband with a
-- priest in it, this is a worse iron hammer.
--
-- A note on the tag, because this weapon only works because of a fix: status_freeze's vulnerability is
-- keyed on `impact`, which is the blunt tag every mace, hammer and censer in the game actually carries.
-- It used to read `crush` -- a word two items in the whole tree used -- so no hammer could shatter the
-- ice it had just made. See the header of data/status/status_freeze.lua.
return {
    name = "Frostfall Hammer",
    description = "Freezes rather than stuns -- and the ice makes its own next blow land far harder.",
    flavor = "The head is always wet, and never in a way anyone likes to think about for long.",
    sprite = "assets/items/frostfall_hammer.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "ice", "melee" },
    hands = 2,
    class = "fighter",
    price = 380,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        cost = { stat = "stamina", amount = 12 },
        -- A shade under the iron hammer's: the second swing is where the number actually lives.
        damage = { 10, 11, 12, 14, 15, 16, 17, 18, 20, 21, 22 },
        effect = function(fx)
            -- The freeze rides the blow (`inflicts`) rather than following it, for the reason the iron
            -- hammer's header gives: hard control applied on the NEXT line arrives after the counter has
            -- already fired from inside fx.damage, so the fighter gets answered by the man it just froze.
            fx.damage(fx.target, { inflicts = "status_freeze" })
        end,
    },
}
