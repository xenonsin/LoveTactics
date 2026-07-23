-- Spellstrike: the mage half of the Battlemage (fighter x mage). A grid charm, like Envenom and the
-- Fire Stone (data/items/consumable/consumable_envenom.lua): the weapons sitting adjacent to it on the
-- 3x3 loadout grid are re-forged -- their hits gain the `magical` tag (routing through magicDefense
-- instead of armour) and set their targets Burning (data/status/status_burn.lua). Steel that carries a
-- spell without a caster's hand: the fighter beside it swings ordinary metal and lands sorcery.
--
-- A CHARM (permanent), not a coating: this is a build decision -- one of nine cells given over to making
-- the whole grid's steel arcane -- rather than a vial that empties (docs/classes.md, the charm/coating
-- split). The elemental debuff is what makes it the Battlemage's rather than any enchanter's.
return {
    name = "Spellstrike",
    description = "Adjacent weapons deal magical damage and set their targets Burning.",
    flavor = "The Arcanum spent centuries deciding steel could not hold a spell. Nobody asked the steel.",
    sprite = "assets/items/utility_spellstrike.png",
    type = "utility",
    tags = { "charm", "fire" },
    class = "mage",
    discipline = "battlemage", -- fighter x mage; the Spellstrike mechanic's first stock
    price = 420,
    repRank = 3,
    aura = {
        appliesTo = { "weapon" },   -- re-forges the neighbouring blades, not consumables
        grantTags = { "magical" },  -- their hits route through magicDefense
        status = { id = "status_burn", opts = { duration = 20 } }, -- the elemental debuff, on a damaging hit
    },
}
