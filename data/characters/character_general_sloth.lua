-- The general of Sloth, and the end of the Bastion's line (docs/story.md, "The Bastion: sloth,
-- designed"). Enemy blueprint; the objective of data/quests/general_sloth.lua.
--
-- Acedia held the greatest post on the Watch and was the order's living emblem -- the doctrine is
-- named for her. When the Bastion wrote her post off she did not hold and she did not die: she
-- NEGOTIATED, her life and her company's for the gate, and the land beyond it paid. The sin is not
-- the cowardice. It is the fifteen years since, spent making the cowardice true -- walking the line
-- telling knights that no post is worth holding, with the authority of a name the order still reads
-- aloud off every Oathkeeper Shield as a martyr's.
--
-- Her rule is in `traits`, and it is a rigged demonstration rather than an attack
-- (data/traits/trait_unrelieved.lua): she swears the party into pairs nobody chose and bites whoever
-- ends a turn alone. The counterplay is the opposite of Wrath's -- not burst, but FORMATION. Move as
-- pairs, keep the huddle tight, and accept that the huddle is exactly where her company's spears want
-- you. Sloth is being stuck, not being outdamaged.
--
-- Statted as a wall rather than a threat: enormous health and defense, real magic resistance, and
-- damage that is frankly poor for a general. She is not trying to kill you. Every turn you spend on
-- her is a turn her sworn pairs are billing you for, so the pressure is the CLOCK -- which is why she
-- can afford to be this slow, and why `assassinate` is the honest objective. Grinding her guard down
-- is the losing line, and it is meant to look tempting.
return {
    name = "Acedia, the Unrelieved",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_sloth.png",
    portrait = "assets/portraits/general_sloth.png", -- large VN portrait for conversations (falls back if missing)
    stats = {
        health = 340, mana = 40, stamina = 90,
        staminaRegen = 2,
        damage = 12, magicDamage = 0, -- poor, and it never climbs: the clock is the weapon
        defense = 22, magicDefense = 16, -- no soft answer the way Ira is soft to magic
        movement = 2, -- she does not chase. She has never once had to
        speed = 2,
    },
    traits = { "trait_unrelieved" },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. The pike is the relic that comes
    -- off her body (data/items/weapon/weapon_forsworn_pike.lua) and the shield is the Bastion's own
    -- rank-4 stock -- she is still, in every visible respect, one of theirs. That is the point of the
    -- silhouette: nothing about her reads as a demon.
    startingItems = {
        false, false,                    false,
        false, "weapon_forsworn_pike",   "armor_oathkeeper_shield",
        false, false,                    false,
    },
}
