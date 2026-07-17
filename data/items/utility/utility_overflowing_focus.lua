-- The Mage's signature relic: the focus that will not let a cast fail for want of mana. It carries the
-- Mage's innate (data/traits/overchannel.lua) -- when the pool runs dry, the shortfall is paid in
-- health, one point per point. Overchannel hangs no hook; it is a capability the cost core reads via
-- Trait.has, and Trait.attach finds it on this item just as it once found it on the character.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. The
-- Mage's blueprint places it in the center of the loadout grid; the deeper its mana curve grows, the
-- less blood each overchanneled spell costs.
--
-- No `class`/`price`: no vendor stocks or buys it. Forged at the Blacksmith, its mana ceiling rising.
return {
    name = "Overflowing Focus",
    description = "When mana runs dry, spells are paid for in health instead.",
    flavor = "An arcanist who refuses to stop casting. It never leaves your hand, and it was never going to.",
    sprite = "assets/items/sig_overflowing_focus.png",
    type = "utility", -- an arcane focus: `bound` (not the type) is what locks it in place
    tags = { "signature" },
    bound = true,
    traits = { "trait_overchannel" },
    maxBonus = { mana = { 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26 } }, -- levels 0..10
}
