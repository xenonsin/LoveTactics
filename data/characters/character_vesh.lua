-- VESH, THE HOLLOW KING: Greed's lieutenant, on floor five's stair. Reviewed over three rounds on
-- 2026-09-25 ("The Dead Hand"). A seated body may carry a name, so he does.
--
-- HE WAS A MAN. A human necromancer who salted the deep seams with gold to draw greedy dwarves down for
-- fresh bodies, and kept what came -- the dead of this floor are his catch, not the mountain's. So he is
-- race human, class mage, discipline necromancer, and TAGGED undead (models/character.lua): a lich is the
-- one dead thing that chose it, and the class he chose is the one he kept.
--
-- HIS BLUE BAR IS THE FIGHT. One pool pays for three things:
--   HIS DEATHS     The Last Rite is Bone-Knit -- a lethal blow is refused for 40 mana and he stands up WHOLE.
--   HIS ARMY       Call the Lured brings a skeleton out of the dark, and each one RESERVES a fifth of his pool
--                  while it stands (a dwarf against a wall, a kobold anywhere else). A skeleton's death frees
--                  the ceiling and refunds nothing. The escort he opens with reserves nothing.
--   HIS SIGNATURE  Foreclosure: a turn's wind-up on a foe's tile, heavy dark damage, and a body it downs rises
--                  as its own skeleton on his side.
-- And the Offering is how he turns a kobold back into mana. So: kill his chaff before he eats it, burst him
-- while his ceiling is low, step off the marked tile. Grave-Chill Inters whoever it strikes, and The Dead
-- Hand takes mana back with every dark blow. Dead kobolds kneel to him (trait_lich).
return {
    name = "Vesh, the Hollow King",
    race = "human",
    undead = true,
    class = "mage",
    discipline = "necromancer",
    tier = 3,
    boss = true, -- the stair's fight: off the execute and Charm tables
    sprite = "assets/chars/vesh.png",
    archetype = "skirmish",
    stats = {
        health = 124, mana = 120, stamina = 20,
        staminaRegen = 2,
        damage = 8, magicDamage = 20,
        defense = 3, magicDefense = 12,
        movement = 3,
        speed = 4,
        skill = 5, luck = 2,
    },
    startingItems = {
        "ability_grave_chill",   "ability_foreclosure",   "ability_call_the_lured",
        "ability_the_offering",  "utility_the_dead_hand", "utility_the_last_rite",
        false,                   false,                   false,
    },
    -- What he drops is what he carries, and the book he kept (Descent.DROPS pays the same list on his stair).
    drops = {
        "ability_foreclosure", "ability_raise_the_owing", "utility_the_dead_hand",
        "utility_ledger_of_the_lured", "ability_call_the_lured",
    },
    defaultAction = "ability_grave_chill",
    ai = {
        { priority = "high", act = "cast", item = "ability_foreclosure",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
