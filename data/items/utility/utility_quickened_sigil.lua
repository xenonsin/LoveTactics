-- Relay Sigil: the Elementalist's grid joker (docs/engines.md). Set in the MIDDLE cell of a row, it
-- carries a cast from one end of that row to the other: cast the item at one end, and the item at the
-- far end fires at the same mark for free, once a turn (Engine.relayPartner; resolveCast runs the relayed
-- working with all of its own machinery and bills nothing for it). A chain built by placement. Renamed
-- from the round's working name Conduit, which the Arcane Conduit already carries.
--
-- Reworked from the Quickened Sigil (2026-11-18). The id stays for saves and the Elementalist's kit.
return {
    name = "Relay Sigil",
    description = "In the middle of a row: casting one end also fires the other end at the same target, free, once a turn.",
    flavor = "The incantation is the same length. She has simply stopped saying it twice.",
    sprite = "assets/items/utility_quickened_sigil.png",
    type = "utility",
    tags = { "arcane", "sigil" },
    class = "elementalist", -- deeper cut of the shelf: buyable only once the elementalist gate is cleared
    unlockLevel = 6,
    relay = true,
    bonus = { speed = 2 },
}
