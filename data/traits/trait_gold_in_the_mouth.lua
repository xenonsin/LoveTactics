-- GOLD IN THE MOUTH: the bearer of Gilded Bread cannot be healed (2026-09-26, the Gilded King's second
-- drop: "Cannot be healed"). The King's curse carried out of his vault, without the gold: a heal aimed at
-- the bearer is refused outright and nothing lands anywhere.
--
-- A FLAG at the one heal funnel (Combat.applyHeal's `refusesHealing`, asked beside the Uncloseable Wound's
-- status so both refusals log the same line), and the preview asks it too. IN A FIGHT ONLY: between fights
-- the bearer rests and mends like anybody else, because the camp and the Ward are not heals, they are time.
return {
    name = "Gold in the Mouth",
    description = "You cannot be healed.",
    refusesHealing = true,
}
