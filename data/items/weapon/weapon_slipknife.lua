-- A dagger, so it owes the family's contract (docs/weapons.md): very quick, and it opens a wound. What
-- it adds over data/items/weapon/weapon_iron_dagger.lua is the Slipstep reflex
-- (data/traits/trait_slipstep.lua) -- hit its bearer from anywhere at all and the knife is not there
-- any more, it is beside you.
--
-- The extra is a rule the whole counter economy is built on, refused rather than beaten. Every other
-- answer in the game is gated by reach, and a dagger has the shortest reach there is: a knife-fighter
-- is precisely the character who never gets to answer anything. This one crosses the gap instead of
-- reaching across it, so the archer picking it off from five tiles away is the one who gets a knife in
-- the ribs -- and the price is billed as a knife's, since a knife is what is actually swung.
--
-- What it costs is position, honestly and every time. The bearer ends its reflex standing in the open,
-- next to something that just attacked it, with whatever else that thing brought. A Slipknife is the
-- blade for a rogue who wanted to be over there anyway.
--
-- Its own bleed is the ordinary 3 -- data/items/weapon/weapon_kingsblood_dagger.lua is the blade that
-- cuts deeper, and this is the one that cuts from somewhere else. Note that the reflex swings the
-- weapon rather than casting its ability, so an answering slip deals damage but leaves no wound: the
-- bleeding is what the rogue does on its OWN turn, and the slip is what it does on yours.
return {
    name = "Slipknife",
    description = "Deals damage and inflicts Bleed. When struck from any range, appear beside the attacker and cut.",
    flavor = "You do not block a knife like this one. You turn around.",
    sprite = "assets/items/slipknife.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    -- Quest-only: `class` with no `price`, so it tallies toward rogue growth but no vendor stocks it and
    -- it can never fall out of the spoils pool (models/spoils.lua). Slipstep is a signature-grade reflex
    -- -- the one counter in the game that distance does not gate -- and a thing that answers a bowshot by
    -- appearing beside the archer should be earned rather than bought.
    class = "rogue",
    traits = { "trait_slipstep" }, -- the whole of the extra; see the file for why it costs what it costs
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, as every dagger is (docs/weapons.md)
        -- What a slip costs, too: an answer is a swing, so this number is the reflex's price as well as
        -- the strike's -- and it doubles for each answer already thrown this round. Deliberately a
        -- notch over the iron dagger's 5, because this blade answers things no other blade can.
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 10 }, -- under the iron dagger: the reflex is what you bought
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_bleed")
        end,
    },
}
