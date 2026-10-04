-- SLEEPER'S CLAWS: the Ground Sloth's bank on a monk's fist (data/items/utility/utility_sleepers_claws.lua).
-- Approved 2026-10-04 on "Sloth's Bestiary", slice A.
--
-- The earning half is the sloth's own (models/sloth_beasts.lua): a turn ended without attacking banks a blow
-- (status_banked, the same badge), up to 3. The spending half is the bare fist's: weapon_unarmed lands once more
-- per banked blow for a bearer carrying `spendsBankOnFist`, and the bank empties. No knock -- the drop text
-- promises the bank, not the sloth's weakness.
local SlothBeasts = require("models.sloth_beasts")

return {
    name = "Sleeper's Claws",
    description = "Each turn you end without attacking banks a blow, up to 3. Your next bare-handed strike lands once more per blow.",
    notAReaction = true,
    spendsBankOnFist = true,
    cap = 3,
    onCast = SlothBeasts.markSwing,
    onTurnEnd = SlothBeasts.bankTurnEnd,
}
