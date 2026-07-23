-- Crawler Mucus: a jar of something that was still moving when it was scraped off. A COATING (see
-- data/items/consumable/consumable_fire_stone.lua for the contract and for what makes one): smear it
-- beside a weapon in the 3x3 grid and that weapon's hits leave their target Rooted -- feet stuck fast
-- to the ground it was standing on.
--
-- The third coating, and the one that is not damage at all. The Fire Stone adds burning and Envenom
-- adds rot; both make a blade hurt more over time. This makes a blade *stop* something, which is a
-- different kind of asking. The Crucible's line on it is that this is the honest version of envy: the
-- alchemist cannot outrun anyone, so it sells the ability to make that stop mattering.
--
-- Root is the pairing this exists for. Bleed taxes moving and Poison taxes waiting (docs/weapons.md,
-- the Envenomed Kris) -- Root removes the first option outright, so a rooted, bleeding, poisoned foe
-- has been walked into a corner three vials wide. That is the Bombardier's whole argument for carrying
-- four consumables instead of a second weapon.
--
-- Short stack and a short root: this is a tempo purchase, not a lockdown. `restorative`-tagged
-- neighbours are left uncoated for the same reason Envenom leaves them -- a healing draught that
-- rooted its patient would be a bug wearing a feature's clothes.
return {
    name = "Crawler Mucus",
    description = "Adjacent weapons and abilities inflict Root on a hit. Spent as they are used.",
    flavor = "Sold by the jar, priced by the jar, and never once described by the jar.",
    sprite = "assets/items/consumable_crawler_mucus.png",
    type = "consumable", -- a coating: it is used up by the weapon it is smeared beside
    tags = { "poison", "coating" },
    class = "alchemist",
    price = 200,
    repRank = 2,
    aura = {
        appliesTo = { "weapon", "ability" },
        exceptTags = { "restorative" }, -- a draught that rooted its drinker is not a coating, it is a mistake
        status = { id = "status_root", opts = { duration = 10 } }, -- ~2 turns: a tempo purchase, not a lockdown
    },
}
