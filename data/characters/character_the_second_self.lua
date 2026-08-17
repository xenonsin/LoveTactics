-- THE SECOND SELF: Envy's mythic, and the most memorable fight in the descent.
--
-- It arrives wearing one of your own company. Not an imitation of one -- Summon.copyOf, the same engine
-- call Livia's Covetous Reflection makes, which is the completed Great Work rather than the Crucible's
-- fragile counterfeit (data/traits/trait_covetous_reflection.lua).
--
-- WHICH ONE IT TAKES IS YOURS TO DECIDE, and that is what keeps it from being a coin flip. Lesser
-- Reflection copies the WEAKEST body it can see (data/traits/trait_lesser_reflection.lua), and the glass
-- around it spends the whole fight stripping blessings to change who that is. So the answer is not a
-- stat check, it is the shape of your company: protect a body and it stops being the cheapest thing on
-- the board.
--
-- IT WAS THE RISKIEST THING PROPOSED AND IT WAS SHIPPED DELIBERATELY. A doppelganger wearing a player's
-- own build is the fight most able to feel unfair, and that is a tuning job rather than a reason to cut
-- it. The two things holding it honest: the copy is of the LEAST of you, and it only comes once
-- (`stacks` gates it), so a long fight cannot fill the board with your own faces.
--
-- Tier 3's band is 81-154 health. Middling: the copy is the threat, not the caster.
return {
    name = "The Second Self",
    kind = "construct",
    tier = 3,
    sprite = "assets/chars/the_second_self.png",
    stats = {
        health = 104, mana = 20, stamina = 22,
        staminaRegen = 2,
        damage = 12, magicDamage = 10,
        defense = 8, magicDefense = 10,
        movement = 4,
        speed = 4,
    },
    startingItems = { "weapon_ashen_echo", "utility_envys_pane" },
    defaultAction = "weapon_ashen_echo",
    -- Basic tactics (models/ai.lua): it holds the middle and answers, which is what a body waiting to be
    -- wounded enough to reflect should do. Charging would trigger its own rule early and badly.
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
