-- Battle Casting: the mage half of the Battlemage (fighter x mage). Spells cost less with a foe in your
-- face, and your weapon strikes hand mana back.
--
-- The inversion the discipline exists for. Every other caster in this game is built to be somewhere
-- else -- range, sight lines, a wall between you and the thing that wants to hit you. This charm is only
-- worth what it costs when something is already swinging, which is why it belongs on a fighter's grid
-- and not on a robe.
--
-- It is also the economy that makes the rest of the shelf run. The Arcane Conduit banks Arcane off
-- casting and spends it sharpening a neighbour; the Resonant Grip turns the last spell into the next
-- swing. Both want a battlemage casting AND swinging in the same fight, and both are unaffordable if
-- every spell is priced for a mage standing safely at four tiles. This is what pays for them.
--
-- The refund is small, and physical only -- a mage refunding itself for casting would be an engine for
-- infinite spells rather than a reason to carry a sword.
return {
    name = "Battle Casting",
    description = "Spells cost less while a foe is adjacent, and your weapon strikes restore mana.",
    flavor = "The safe distance is a convention. She has read the same books and drawn a different line.",
    sprite = "assets/items/utility_battle_casting.png",
    type = "utility",
    tags = { "charm", "magical" },
    class = "mage",
    discipline = "battlemage",
    price = 345,
    unlockQuests = 2,
    traits = { "trait_battle_casting" },
}
