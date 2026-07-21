-- Amana, the priest companion (devotion), and the answer to Lust at the head of the Cathedral's line
-- (docs/story.md, "The other seven"). A woman, a gender-neutral name, the virtue buried and not stamped:
-- Amana is the Arabic amana -- a trust placed in your hands, to be returned intact and never drawn from
-- -- which is her whole rule, "gives what is offered, refuses what is not," the way Saber's name is
-- patience in another tongue (character_saber.lua).
--
-- SAME WOUND AS THE GENERAL SHE ANSWERS. Both Amana and Luxuria (character_general_lust.lua) were taken
-- by the Cathedral as children -- oblates given to the faith without consent, their birth-names taken and
-- replaced. The faith "takes what is not offered" and calls it holiness. Luxuria drew from that the
-- lesson that the faithful owe everything, and became the hand that takes; Amana drew the opposite -- that
-- anything taken is theft dressed as faith -- and will only ever give. She is the answer the general
-- refused.
--
-- HER KIT IS GIVING MADE MECHANICAL, and she bears no edge (the cleric taboo, docs/classes.md): a censer,
-- not a blade. Rowan decides where you stand; Amana decides who survives. Heal to mend (which also opens
-- her signature), the Martyr's Icon to take a mortal blow for the ally beside her, and the Reliquary of
-- the Kept Trust in the center (data/items/utility/utility_reliquary_kept_trust.lua), which wards the
-- whole company once she has given three times and keeps nothing back for herself.
--
-- The other half of her rule -- her will cannot be taken -- rides on that same bound reliquary
-- (data/traits/trait_devotion_unbidden.lua): Charm sheds off her, and Lust's Rapture finds nothing held
-- back to seize, not from strength but because she gave it all away first. It lives on the relic and not
-- here because a blueprint's own `traits` field is never collected -- only an item's is (models/trait.lua).
-- `boss = true` gives the recruit fight its integrity: the Cathedral brands its own refuser fallen and
-- hires you to purge her (data/quests/fallen_confessor.lua); best her and she is yours (Player.recruit),
-- exactly as the Colosseum keeps Saber. It goes inert the moment she is an ally, when only the reliquary's
-- refusal still stands.
return {
    name = "Amana",
    sprite = "assets/chars/amana.png",
    portrait = "assets/portraits/amana.png", -- large VN portrait for conversations (falls back if missing)
    class = "priest",
    boss = true,
    stats = {
        health = 62, mana = 40, stamina = 50,
        staminaRegen = 2,
        damage = 5, magicDamage = 9,   -- feeble on purpose: she does not kill
        defense = 8, magicDefense = 13, -- warded against the magic her line traffics in
        movement = 3,
        speed = 3,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The Reliquary is the build-around in the
    -- center; Heal beside it is what opens it, and the Martyr's Icon is the giving she can make with her
    -- body when there is no mana left to mend with.
    startingItems = {
        "ability_heal",         "weapon_censer",                "consumable_healing_potion",
        "utility_martyrs_icon", "utility_reliquary_kept_trust", false,
        false,                  false,                          false,
    },
    defaultAction = "ability_heal",
}
