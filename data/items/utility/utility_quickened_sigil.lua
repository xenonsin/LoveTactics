-- The Quickened Sigil: the magic beside it in the 3x3 grid costs less TEMPO. The spell is not cheaper
-- in mana and not weaker -- it simply bills fewer ticks at the end of the turn, so the caster comes
-- back around sooner (Combat.actionSpeed, the single reader the timeline ghost, the hover preview and
-- the live endTurn all quote).
--
-- One of the five sigils; see data/items/utility/utility_distant_sigil.lua for the family.
--
-- The sigil that touches the only currency this game actually has. Mana is a pool you refill and
-- health is a pool you refill; initiative is the one thing nobody gets back, and every other charm in
-- the catalogue argues about the size of a number while this one argues about when your next turn is.
-- Three ticks off a Fireball's ten is, over a long fight, an extra Fireball.
--
-- Priced accordingly, and floored: Combat.actionSpeed clamps the result at 1, so no arrangement of the
-- grid may ever make a cast free. That floor is doing real work rather than being defensive -- a
-- zero-speed action would let a unit act, keep initiative 0, and act again forever. The rule is made
-- unreachable by arithmetic instead of by a warning nobody would read.
--
-- Compare Haste (data/status/status_hasted.lua), which discounts COSTS and halves the walk. This
-- discounts the action's tempo and nothing else, is permanent rather than a window, and applies to one
-- corner of the grid rather than to the whole unit. Stacking both is entirely legal and entirely the
-- point of a mage who has decided that going first is the only thing that matters.
return {
    name = "Quickened Sigil",
    description = "Adjacent magic costs less time -- the caster comes back around sooner.",
    flavor = "The incantation is the same length. She has simply stopped waiting for it to finish.",
    sprite = "assets/items/utility_quickened_sigil.png",
    type = "utility",
    tags = { "arcane", "sigil" },
    class = "mage",
    price = 520,
    repRank = 4,
    aura = {
        appliesTo = { "ability", "weapon" },
        requiresTags = { "magical" },
        -- NEGATIVE is faster. Folded into Combat.actionSpeed and floored there at 1.
        speedBonus = { -1, -1, -2, -2, -2, -3, -3, -3, -4, -4, -4 },
    },
}
