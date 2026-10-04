-- BAKU, THE DREAM-EATER: an elite of Sloth's seat ("Sloth's Bestiary", 2026-10-04, slice E). A chimera out of the
-- old country's bedside charms -- a tapir's head, an elephant's trunk and tusks, a tiger's feet, an ox's tail --
-- that was asked to eat nightmares and has since stopped asking whose.
--
--   DREAM-EATING   at the start of its turn it feeds on every Asleep or Dormant body within 3, on either side: a
--                  tenth of its health healed and +2 Damage for each (trait_dream_eating, status_dream_fed)
--
-- THE COUNTERPLAY, STATED, and it is the review's: wake your own sleepers -- hit them -- to starve it, and kill the
-- moths that put them under first. It always stands in its cloud of Poppy-Moths (encounter_sloth_baku), so every
-- sword that reaches a moth sets the table. The meal is read fresh each turn, so a company that wakes its line
-- takes the damage off it on its very next turn; the heal is the half that keeps.
--
-- A BEAST, not its own race: a chimera is a thing of many animals, and the Chimera of the wood is a beast too.
-- Tier 3's band is 81-154 health; mid-band, because the moths are its armour and the meal its regeneration.
return {
    name = "Baku, the Dream-Eater",
    race = "beast",
    tier = 3,
    boss = true, -- off the execute and Charm tables, as every elite is
    sprite = "assets/chars/baku.png",
    archetype = "aggressive",
    stats = {
        health = 118, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 12, magicDamage = 0,
        defense = 7, magicDefense = 8,
        movement = 4,
        speed = 5,
        skill = 6, luck = 5,
    },
    -- A tiger's hide on a tapir's bulk: an edge glances off and a club thuds in, and a spear finds the soft
    -- underside. Sums to zero (docs/bestiary.md). The nightmares it has eaten sit in it, so dark turns.
    resist = { slash = 2, impact = 1, pierce = -3, dark = 3 },
    startingItems = {
        "weapon_baku_tusks", "utility_dream_eating", false,
        false,               false,                  false,
        false,               false,                  false,
    },
    drops = { "utility_bakus_ward" },
    defaultAction = "weapon_baku_tusks",
}
