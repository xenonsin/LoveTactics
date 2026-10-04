-- HIBERNAL HIDE: the Old Sloth's trophy rule (data/items/armor/armor_hibernal_hide.lua), on a Warden. Approved
-- 2026-10-04 on "Sloth's Bestiary", slice A.
--
-- The blow that wakes the wearer from Sleep lands at half: a Sleep (or Dormant) landing on the wearer carries
-- damageTakenScale 0.5 on its instance, read by Status.damageTakenScale, so the halving is quoted by the hover and
-- dealt by the blow alike, and it leaves with the sleep. The first blow the wearer throws after waking deals 50%
-- more (damageBonusVs, half of the weapon and the stat behind it), and an attack spends it. All in
-- models/sloth_beasts.lua. `notAReaction`: a sleeping body's reflexes are gagged, and waking is not a reflex.
local SlothBeasts = require("models.sloth_beasts")

return {
    name = "Hibernal Hide",
    description = "Blows that wake you from Sleep deal half. Your first blow after waking deals 50% more.",
    notAReaction = true,
    woken = 0.5,
    bonus = 0.5,
    onStatusApplied = SlothBeasts.hibernate,
    onDamaged = SlothBeasts.checkWake,
    onTurnStart = SlothBeasts.checkWake,
    damageBonusVs = SlothBeasts.wakeBonus,
    onCast = SlothBeasts.spendWake,
}
