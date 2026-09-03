-- COMMON. The caster's Full Skin. Mana persists between battles (models/player.lua), so a raised ceiling
-- here is a larger tank for the whole floor rather than a refill -- which is exactly why it pairs with
-- The Overreach, the uncommon that makes every cast cost more.
return {
    name = "The Overfull Flask",
    blurb = "+%d maximum mana for the whole company.",
    tier = "common", mark = "Fl",
    scale = { 4, 4 },
    maxBonus = { mana = 4 },
}
