-- Thinblood Rime: a phial of grey frost smeared along a blade. Everything the blade touches is slowed
-- and, for a little while, cannot be mended at all.
--
-- A COATING (the `aura` block -- see Combat.auraApplies and the fold in resolveCast's fx.damage), which
-- is the alchemist's own contract: it does nothing itself, it sits in the grid next to somebody else's
-- weapon, and it makes that weapon carry something it could not otherwise carry. Envy's whole shelf
-- covets other people's power rather than casting any (docs/classes.md), and this is that stated as
-- plainly as the mechanic allows.
--
-- WHAT IT ACTUALLY SELLS is the Unclosing Wound, and it is the cheapest way in the game to get one.
-- Nothing else the party owns can close an enemy priest's mending -- a focused kill that three people
-- committed to could always be undone by one cast, and the only answer was "kill the priest first",
-- which is the same problem one tile over. Coat a blade in this and every blow the party lands buys a
-- window where healing simply does not happen.
--
-- Short windows, deliberately, and stacked from repeated hits rather than from one: the block is a
-- couple of turns per application, so a single arrow does not decide a fight. What decides it is a
-- front-liner landing three blows in a row while the rest of the party finishes somebody.
--
-- The cripple is the quieter half and the reason the coating is worth a slot in a fight with no healer
-- in it at all: a slowed target is a target that cannot disengage from the person who coated the blade.
--
-- CHARGES, like every coating: it is spent as the workings it sharpens land, and then the slot is
-- empty until it is restocked. A coating that lasted forever would not be a coating.
return {
    name = "Thinblood Rime",
    description = "Coats adjacent weapons: their hits slow the target and stop it being healed.",
    flavor = "The Crucible sells it by the phial and asks that you not describe what you use it on.",
    sprite = "assets/items/consumable_thinblood_rime.png",
    -- `type = "consumable"` is what MAKES it a coating: Combat.auraSpent reads the type and the stack,
    -- so the phial empties as the blades beside it are swung (Combat.spendAuras). There is no separate
    -- "this is spent" flag -- see data/items/consumable/consumable_envenom.lua, the pair this
    -- distinction between a coating and a charm was originally drawn for.
    type = "consumable",
    tags = { "coating", "ice" },
    class = "alchemist",
    price = 360,
    repRank = 3,
    maxStack = 4, -- the charges: each sharpened working that lands spends one
    aura = {
        appliesTo = { "weapon" },
        grantTags = { "ice" },
        -- One status per aura block (see adjacencyAura), so the coating names the one that matters:
        -- the heal block is what anybody is buying this for, and the `ice` tag it also grants is what
        -- makes the blade read as cold to everything downstream.
        status = { id = "status_unclosing_wound", opts = { duration = 8 } },
    },
}
