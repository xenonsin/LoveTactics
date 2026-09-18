-- Xin, the priest companion (devotion), and the answer to Lust at the head of the Cathedral's line
-- (docs/story.md, "The other seven"). A woman, a gender-neutral name, the virtue buried and not stamped:
-- Xin is the Chinese 信 -- trustworthiness, the character drawn as a person standing beside their own
-- word, and one of the Confucian Five Constants the alchemist's 仁 was taken from (character_ren.lua).
-- It is her whole rule, "gives what is offered, refuses what is not," the way Saber's name is patience
-- in another tongue (character_saber.lua) -- and it is the exact word for what the Cathedral is not,
-- a house whose register says one thing while its pit says another.
--
-- THE ANSWER TO THE GENERAL SHE FACES, but not her kin. Luxuria (character_general_lust.lua) is an
-- outside human who pacted with the Demon Lord and posed as the Cathedral's revered Saint. Xin was
-- taken by the Cathedral as a child like many, but raised on the ACOLYTE (clergy) track -- never made a
-- soldier, never blooded. Luxuria is the sin, "takes what is not offered"; Xin is its answer, "gives
-- what is offered, refuses what is not." Same axis, opposite verbs; she is the answer the general refused.
-- She turns on the church not by resisting a corruption but as a WITNESS: she saw the blooding kill
-- children and the bodies dumped in pits (docs/story.md, "The Cathedral").
--
-- HER KIT IS GIVING MADE MECHANICAL, and she bears no edge (the cleric taboo, docs/classes.md): a
-- crozier, not a blade. Rowan decides where you stand; Xin decides who survives. Heal at range (which
-- also opens her signature), and the Reliquary of the Kept Trust in the center
-- (data/items/utility/utility_reliquary_kept_trust.lua), which wards the whole company once she has
-- given three times and keeps nothing back for herself.
--
-- SHE DOES NOT ARRIVE WITH THE MARTYR'S ICON, and the reason is the size of the gift rather than the fit
-- of it. It fits her exactly -- an unconditional once-per-battle death-save spent on the body beside her
-- IS her vow written as an item -- and that is the problem. Handed over with an early recruit it is a
-- larger thing than her own signature, on a body the player did not build toward it, and it answers the
-- question her whole kit is supposed to keep asking: whether the company can afford to lose somebody.
-- The Icon is still in the game and still hers to carry if the player finds one
-- (data/items/utility/utility_martyrs_icon.lua, dropTier 2, and the Bulwark's kit) -- the cell is left
-- open rather than refilled. Nothing about her reads differently for its absence: the Reliquary already
-- says "keeps none of it for herself," at a price a recruit can be handed.
--
-- THE CROZIER IS HERE BECAUSE THE RELIQUARY IS ALREADY THE AURA. She carried the plain censer until the
-- two of them read as one idea said twice: walking smoke that Blesses whoever stands beside her, under a
-- ward that lays Aegis and Regeneration on whoever stands beside her. The censer stays with the generic
-- priest (character_priest.lua), whose centre is deliberately empty and who needs an ambient verb to
-- have one at all. Hers is full, and a second aura only made the first one quieter.
--
-- What the crozier hands her instead is the turn economy her own loop cannot pay for. Her pool is 40 and
-- it does not regenerate: three Heals at 10 open the Reliquary at 18, which is 48. The giving she is
-- built around does not fit in the body she was authored with, and the Focus swap
-- (data/items/weapon/weapon_crozier.lua) is where the rest of it comes from -- a turn spent not acting,
-- which is the only kind of turn she was ever going to be able to spare. `covers` then hands four of
-- that mana to every adjacent ally, so where she plants to meditate is still a decision about somebody
-- else: a different currency from the ward, paid on a beat she chooses rather than laid down wherever
-- she happens to walk. (Under auto-battle the swap is inert -- an AI plan's `wait` ends in Combat.pass
-- and never Combat.focus, so models/ai.lua cannot Focus at all. That hole is engine-wide and older than
-- this kit: Rowan's shield sits in it too.)
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
    name = "Xin",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/xin.png",
    portrait = "assets/portraits/xin.png", -- large VN portrait for conversations (falls back if missing)
    class = "priest",
    boss = true,
    -- She does not kill (damage 5), so she must not be left on the aggressive default that would send
    -- her up to punch. `support` reads the company's wounds before the enemy's throats (models/ai.lua).
    archetype = "support",
    -- PERSONAL GROWTH (models/growth.lua): two points a level she keeps in any class. What she gives
    -- and what she will not be taken by -- the trust deepens, and the ward against the magic her line
    -- traffics in holds. Nothing offensive, which is the same sentence her damage stat already makes.
    personalGrowth = { mana = 1, magicDefense = 1 },
    stats = {
        health = 62, mana = 40, stamina = 13,
        staminaRegen = 2,
        damage = 5, magicDamage = 9,   -- feeble on purpose: she does not kill
        defense = 8, magicDefense = 13, -- warded against the magic her line traffics in
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 9,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The Reliquary is the build-around in the
    -- center; Heal beside it is what opens it, and the crozier above is what pays for the three casts.
    -- The cells around that trio are open on purpose -- see the Martyr's Icon note in the header.
    startingItems = {
        "ability_heal",         "weapon_crozier",               "consumable_healing_potion",
        false,                  "utility_reliquary_kept_trust", false,
        false,                  false,                          false,
    },
    defaultAction = "ability_heal",
    -- THE TWO ITEMS THAT ARE THIS UNIT, named for the same reason every hall hero names them: a base
    -- class is met at their house's own posting on a floor now (models/errand.lua) and joins at that
    -- house's counter (models/vendor_visit.lua), and this is the pair its card is written from.
    signatureWeapon  = "weapon_crozier",
    signatureAbility = "utility_reliquary_kept_trust",
    -- Basic tactics (models/ai.lua): giving made mechanical. Reach for Heal the instant an ally slips
    -- below two-thirds -- the Reliquary and the Martyr's Icon carry the rest of her giving themselves.
    ai = {
        { priority = "urgent", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
        -- HER BOUND RELIC (utility_reliquary_kept_trust): three given heals open it, and it lays Aegis
        -- and Regeneration over every ally but herself. A band under the Heal, and shallower, which is
        -- the division of labour between them: the Heal answers the dying, the reliquary wards the worn
        -- before they get there. (The condition reads the whole side, herself included -- the cast
        -- spares her either way, which is the point of it.)
        { priority = "high", act = "support", item = "utility_reliquary_kept_trust",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.75 } },
    },
}
