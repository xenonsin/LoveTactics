-- TWOFOLD HAUBERK: the Faceless Colossus's drop, on the bulwark's shelf. Reviewed 2026-10-01..03 ("Envy's
-- Bestiary").
--
-- The heap's two faces worn as one coat: the more of them there are around you, the more of it answers. Counted at
-- the start of your turn and held until the next (trait_twofold_hauberk), so stepping out of a crowd does not shed
-- it mid-round and walking into one does not pay until you have stood there.
local Curve = require("models.curve")

return {
    name = "Twofold Hauberk",
    description = "At the start of your turn, gain +3 defense for each foe within 2, up to 2.",
    flavor = "Two coats of mail, worn by something that had two of everything else as well.",
    sprite = "assets/items/armor_twofold_hauberk.png",
    type = "armor",
    tags = { "plate" },
    class = "bulwark",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_twofold_hauberk" },
    bonus = { defense = Curve.ramp(4, 14), movement = -1 },
}
