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
--
-- IT CLIMBS IN WHOLE STEPS rather than a point a rung, and it is the one magnitude on this charm that
-- does. The refund is paid per BODY a blow lands on (models/combat.lua pays it inside dealDamage), so
-- a cleave collects it three times in one swing; ramp(3, 13) would put 39 mana a turn on an axe and
-- make the sword the spell budget rather than the reason for one. Five steps from 3 to 8 over the
-- whole ladder keeps a forged swing worth taking without paying for the working twice. Named in
-- tests/curve_spec.lua's STEP_CURVES, which is where the exception is bought and checked.
--
-- BOTH FIGURES ARE WHAT THE BENCH BUYS, and until they were authored as curves there was nothing on
-- this charm for a level to raise at all -- no ability, no bonus, no aura -- so Item.isUpgradable
-- refused it and the forge would not take it in. `traitParams` is the seam (models/trait.lua's
-- Trait.param): the item names the trait's tunables, models/item.lua resolves them per level like any
-- other magnitude, and the Spell Discount and Strike Refund rows quote what this copy is actually
-- worth. Which is also why the description names neither number -- 30% and 3 at the base, 40% and 8
-- fully forged, and prose can only ever say one of them.
local Curve = require("models.curve")

return {
    name = "Battle Casting",
    description = "Reduces the mana cost of your spells while a foe is adjacent. On damage dealt with a weapon: restore mana.",
    flavor = "The safe distance is a convention. She has read the same books and drawn a different line.",
    sprite = "assets/items/utility_battle_casting.png",
    type = "utility",
    tags = { "charm", "magical" },
    class = "battlemage",
    price = 330,
    unlockQuests = 3,
    traits = { "trait_battle_casting" },
    traitParams = {
        meleeDiscount = Curve.ramp(30, 40), -- percent off a working thrown in somebody's face
        -- Mana handed back by a landed non-magical blow. A literal list because it counts in whole
        -- steps: see the note up top, and tests/curve_spec.lua's STEP_CURVES, which names it.
        strikeRefund = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
    },
    -- a mage that means to be stood next to
    bonus = { defense = 1 },
}
