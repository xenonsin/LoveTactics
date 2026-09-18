-- Gyeom, the mage companion (humility), and the answer to Pride at the head of the Arcanum's line
-- (docs/story.md, "The Arcanum"). A woman, a gender-neutral name, the virtue buried and not stamped:
-- Gyeom is the Korean 謙 -- humility, the I Ching's hexagram of Modesty, the only one whose every line is
-- auspicious -- the way Saber's name is patience and Kaya's is enough (character_saber.lua,
-- character_kaya.lua). The direct model is Frieren's Fern: no prodigy, just the one who trained every day.
--
-- THE ANSWER TO THE GENERAL SHE FACES, but not her kin. Sublimitas (character_general_pride.lua) is a
-- human who pacted with the Demon Lord for perfect comprehension -- one glance at a working and she owns
-- it -- and is certain she has the measure of every mage she can see. Gyeom is the mage she cannot
-- measure. She showed no gift; she did her best, again and again, and grew formidable, and she still holds
-- she has more to learn. Pride "answers every spell with your own"; humility "meets a spell with a
-- better-practised self, not a bigger one." Same axis, opposite verbs; she is the answer the general refused.
-- She turns on the Arcanum not by resisting a corruption but as a WITNESS who would not call the human
-- cost acceptable just because it was useful (docs/story.md, "The Arcanum").
--
-- HER KIT IS PRACTICE MADE MECHANICAL, and she reads WEAK on purpose -- low displayed magic, a plain wand
-- and a single bolt around the build-around: the Ledger in the center
-- (data/items/utility/utility_ledger.lua), which banks a little strength from every action she takes
-- (data/traits/trait_ledger_diligence.lua) and, once she has done her best four times over, RELEASES what
-- she kept hidden in one heavy strike. She peaks late; a long fight is study, not downtime.
--
-- The other half of her rule -- she cannot be answered -- needs no second hook and rides on that same
-- concealment: Pride answers only what is SHOWN (data/traits/trait_counter_magic.lua), and a spell
-- answered off her suppressed value is answered off nothing. You can glance a spell; you cannot glance the
-- hours she never put on display. It lives on the Ledger's trait and not here because a blueprint's own
-- `traits` field is never collected -- only an item's is (models/trait.lua).
--
-- `boss = true` IS INERT, AND WAS ALWAYS AIMED AT A FIGHT THAT DOES NOT EXIST. It is meant to give a
-- recruit fight its integrity -- immune to execution, Charm and Polymorph, so besting her is earned --
-- the way it does for Saber, who really is fought at the Colosseum. SHE IS NEVER FOUGHT. Her posting is
-- won against the crew holding the ground, and `character_gyeom` appears in that quest file exactly once,
-- as `rewardCharacter`. Left set because it costs nothing and would matter the day somebody writes a
-- fight she stands on the far side of; do not read it as evidence that one exists.
--
-- HER POSTING IS data/quests/arcanum/quest_arcanum_slot_01.lua, "As Far As She Got": she walked into the
-- rift alone to find out how deep she could get, reached the first floor, and stopped, because a crew is
-- holding it and her count does not work with one body. Take the ground and she comes with you.
--
-- TWO EARLIER DESCRIPTIONS OF THAT QUEST ARE WRONG AND BOTH ARE WORTH KNOWING ABOUT. This header used to
-- cite `data/quests/arcanum_the_radical.lua` -- a crown-backed manhunt for the college's own radical --
-- and that file has never existed; the manhunt is what docs/story.md tells about her, not what the game
-- runs. The quest ITSELF was then "The Sunken Sanctum", a flooded reading room the rift had copied and
-- looters had reached first, and that was re-premised on 2026-09-16 with the rest of the campaign fiction
-- it belonged to. Depth is the score now and the dungeon is new every descent, so there is no copied
-- place down there to loot.
--
-- SHE IS THE SCRIPTED COMPANION NOW (models/descent.lua's Descent.SCRIPTED_COMPANION): met on floor one of
-- every descent until she joins, because the company walks out of Act 0 with three against an expedition
-- cap of four and the seat that is open is the magic one. Read the note on that constant before moving
-- her -- it carries the argument, including what her late-paying Ledger costs a first-time player.
return {
    name = "Gyeom",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/gyeom.png",
    portrait = "assets/portraits/gyeom.png", -- large VN portrait for conversations (falls back if missing)
    class = "mage",
    boss = true,
    -- 56 health next to a swordsman is a body. Like every mage she keeps her distance (models/ai.lua),
    -- which is also how the single bolt she shows keeps finding range turn after turn.
    archetype = "skirmish",
    -- PERSONAL GROWTH (models/growth.lua): two points a level she keeps in any class, and hers is the
    -- one this whole mechanic was worth adding for. Gyeom showed no gift; she trained every day and
    -- grew formidable. A body that gets better BY LEVELLING, in the working and in the reserve to keep
    -- doing it, is that sentence written as arithmetic rather than said in a header.
    personalGrowth = { magicDamage = 1, mana = 1 },
    -- REBALANCED TO THE MAGE TEMPLATE, 80/18 (data/characters/character_mage.lua), which restores the
    -- standing rule rather than excusing another body from it: a companion copies its generic's magic side
    -- whole, and Rowan holds the knight's 15/4, Saber the fighter's 5/3, Clem the rogue's 8/3.
    --
    -- SHE SHIPPED AT 46/6 AND ONE LINE OF ARITHMETIC CONDEMNS IT. Per-hit magic damage is `ability power +
    -- the caster's MagicDamage - MagicDefense` (models/combat.lua), so on floor one the AVATAR threw HER
    -- Fire Bolt for 6+16 = 22 and she threw it for 6+6+2 = 14. A classless body that was handed a sword
    -- out-cast the specialist by half again, from turn one, with the same spell. And 6 sat below both
    -- healers (Xin 9, Ren 8), each of whose header says outright that she does not kill. A mage who is
    -- the worst caster in the game is not understated, she is broken.
    --
    -- "SHE READS WEAK ON PURPOSE" WAS BUYING NOTHING, and that is what settles the number. The claim was
    -- that a suppressed sheet is her edge against Pride -- "a spell answered off her suppressed value is
    -- answered off nothing" -- but data/traits/trait_counter_magic.lua reads no such value. The counter is
    -- FLAT: it unravels a single-target spell whole, for a fixed mana price, and its own header says it
    -- "eats a Meteor exactly as it eats a spark". So the suppression was prose describing a mechanism that
    -- was never implemented, and it was being paid for in every fight of the game to buy an interaction in
    -- one that does not exist. The real counter-play against Pride is the cooldown -- bait the reflex with
    -- a cheap cast, then land the one that matters -- which is exactly the shape of her kit (a stream of
    -- bolts, then the Release) and works at any base at all.
    --
    -- WHAT THE CHARACTER IS NOW, since it is not "the weak one": she is the mage who was never a prodigy
    -- and trained anyway, and that reads in the ARC rather than in a low sheet. She arrives a full mage --
    -- 18 against the avatar's 16 -- and Diligence still carries her up from there while a fight runs, so a
    -- long fight is study and not downtime (data/traits/trait_ledger_diligence.lua). The Release rose with
    -- her for free, 32 -> 44, because it scales off MagicDamage; its own curve was left alone.
    stats = {
        -- 80 is the mage template's pool, and it was never the judgment call: "a long fight is study, not
        -- downtime" is unsayable on a body that is dry by the third cast. 46 bought two bolts and a Release.
        health = 56, mana = 80, stamina = 10,
        staminaRegen = 2,
        -- The mage's own number. She is the specialist; she out-throws the reference body
        -- (models/balance.lua's REFERENCE avatar, at 16) from the turn she joins, which is what every
        -- other companion's class side does for its own school.
        damage = 4, magicDamage = 18,
        defense = 7, magicDefense = 11, -- warded against the magic her line traffics in
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 4,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The Ledger is the build-around in the
    -- center; a plain wand and a single bolt are all she shows, and the mana potion is what keeps the
    -- practice going long enough to Release.
    startingItems = {
        "weapon_wand",  "ability_fire_bolt", "consumable_mana_potion",
        false,          "utility_ledger",    false,
        false,          false,               false,
    },
    defaultAction = "weapon_wand",
    -- THE TWO ITEMS THAT ARE THIS UNIT, named for the same reason every hall hero names them: a base
    -- class is met at their house's own posting on a floor now (models/errand.lua) and joins at that
    -- house's counter (models/vendor_visit.lua), and this is the pair its card is written from.
    signatureWeapon  = "weapon_wand",
    signatureAbility = "utility_ledger",
    -- Basic tactics (models/ai.lua): the Ledger only pays out if she is still standing to keep banking
    -- into it (utility_ledger.lua) -- every turn she survives is a turn of practice, and the Release
    -- she is built around is four turns of it away. So the one instinct worth authoring is not to trade
    -- when a glass body is caught: break off under a third health and let the skirmish posture keep the
    -- range the bolt wants. The concealment that makes her unanswerable rides on the Ledger's trait, not
    -- here (trait_counter_magic.lua), so nothing about it belongs in this list.
    ai = {
        { priority = "emergency", act = "retreat", when = { subject = "self", test = "hp_pct_below", value = 0.3 } },
        -- HER BOUND RELIC (utility_ledger): four actions written down, then the one strike she kept
        -- back. Spent the moment something stands inside its three tiles -- there is nothing to save it
        -- FOR, since taking the four actions is what charges it again. Under the retreat, because a
        -- glass body that is bloodied breaks off first and collects the debt from further away.
        { priority = "high", act = "attack", item = "utility_ledger", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "within", value = 3 } },
    },
}
