-- Amana, the priest companion (devotion), and the answer to Lust at the head of the Cathedral's line
-- (docs/story.md, "The other seven"). A woman, a gender-neutral name, the virtue buried and not stamped:
-- Amana is the Arabic amana -- a trust placed in your hands, to be returned intact and never drawn from
-- -- which is her whole rule, "gives what is offered, refuses what is not," the way Saber's name is
-- patience in another tongue (character_saber.lua).
--
-- THE ANSWER TO THE GENERAL SHE FACES, but not her kin. Luxuria (character_general_lust.lua) is an
-- outside human who pacted with the Demon Lord and posed as the Cathedral's revered Saint. Amana was
-- taken by the Cathedral as a child like many, but raised on the ACOLYTE (clergy) track -- never made a
-- soldier, never blooded. Luxuria is the sin, "takes what is not offered"; Amana is its answer, "gives
-- what is offered, refuses what is not." Same axis, opposite verbs; she is the answer the general refused.
-- She turns on the church not by resisting a corruption but as a WITNESS: she saw the blooding kill
-- children and the bodies dumped in pits (docs/story.md, "The Cathedral").
--
-- HER KIT IS GIVING MADE MECHANICAL, and she bears no edge (the cleric taboo, docs/classes.md): a censer,
-- not a blade. Rowan decides where you stand; Amana decides who survives. Heal to mend (which also opens
-- her signature), the Martyr's Icon to take a mortal blow for the ally beside her, and the Reliquary of
-- the Kept Trust in the center (data/items/utility/utility_reliquary_kept_trust.lua), which wards the
-- whole company once she has given three times and keeps nothing back for herself.
--
-- The other half of her rule -- she cannot be taken -- rides on that same bound reliquary
-- (data/traits/trait_devotion_unbidden.lua): Charm sheds off her, and Lust's Rapture finds no purchase,
-- not from strength but because she is UNBLOODED -- there is none of Luxuria's blood in an acolyte to
-- seize or command. It lives on the relic and not here because a blueprint's own `traits` field is never
-- collected -- only an item's is (models/trait.lua).
-- `boss = true` gives the recruit fight its integrity: the Cathedral brands its own acolyte fallen and
-- hires you to purge her (data/quests/fallen_confessor.lua); best her and she is yours (Player.recruit),
-- exactly as the Colosseum keeps Saber. It goes inert the moment she is an ally, when only the reliquary's
-- refusal still stands.
return {
    name = "Amana",
    sprite = "assets/chars/amana.png",
    portrait = "assets/portraits/amana.png", -- large VN portrait for conversations (falls back if missing)
    class = "priest",
    boss = true,
    -- She does not kill (damage 5), so she must not be left on the aggressive default that would send
    -- her up to punch. `support` reads the company's wounds before the enemy's throats (models/ai.lua).
    archetype = "support",
    stats = {
        health = 62, mana = 40, stamina = 13,
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
    -- Basic tactics (models/ai.lua): giving made mechanical. Reach for Heal the instant an ally slips
    -- below two-thirds -- the Reliquary and the Martyr's Icon carry the rest of her giving themselves.
    ai = {
        { priority = "urgent", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
    },
}
