-- SABER'S OPENING. A fighter is waiting at a dead end with her blade already out, a long way from anywhere
-- she was sent. No house sent her and nobody is paying her: she came in looking for a fight worth having,
-- and the company is the first thing down here that might be one.
--
-- WHAT SHE IS, kept from the debut this used to be: Saber fights for JOY, which is the opposite pole from
-- the circle's general, who fights because the sand was the only place she was ever free. She carries
-- The First Motion (weapon_first_motion.lua), which hits hardest into a target at FULL health, so her
-- opening blow on a fresh company is the largest number a new player has seen -- and the exact rule Wrath's
-- general inverts. She signs not because she was beaten but because it was the most fun she has had in
-- years ("Nobody reads the opening").
--
-- RESTORED 2026-10-14 (data/quests went in 92ff549d, and with it every way a companion could join).
-- ONLY THE BOUT CAME BACK. The arena debut around it -- the concourse card, the undercard that taught the
-- net, the walk off the sand (`followUp`) -- belonged to a campaign that no longer exists, and nothing on
-- the descent's errand payout reads any of it. What the bout keeps, and the one body it swapped:
--
--   * SABER'S TWIN (character_saber_bout), so nothing about the bout follows her home.
--   * SOMETHING THAT PUTS A BODY IN FRONT OF HER SWING. It was a Trapper, rooting the target she was
--     about to commit to. SHE IS MET IN WRATH now, the Colosseum's own circle (Descent.SINS' `vendor`,
--     Descent.dealCompanion), and the Blood Ring is where a fighter looking for a fight worth having
--     would have been standing -- so the setup comes from its own cast: an ORC SPEAR-HURLER, whose Hooked
--     Spear drags a body in beside the line. Same job as the net (deliver the target), rung 1 and soft, so
--     a company that reads the fight drops it first and the pulls stop.
--   * THE SAND (`layout = "colosseum_sand"`), whose walls funnel a dodging body toward rigged edges so her
--     telegraphed swing has ground that answers it.
--
-- NO GOODS: the Ledgeman's Axe and the Reckless Cuirass are fighter-ladder finds now. The reward IS the
-- companion, which this blueprint always said.
return {
    name = "The Opening Nobody Reads",
    description = "A fighter is waiting at a dead end with her blade already out, a long way from " ..
        "anywhere she was sent. She is not lost and she is not leaving.",
    difficulty = "Easy",
    sponsor = "colosseum",
    outro = "conversation_colosseum_slot_01_outro",
    rewardGold = 60,
    rewardCharacter = "character_saber",
    -- READ ONLY BY models/balance.lua, which still measures a quest's bodies at a campaign standing:
    -- the standing at the first floor of the circle she is met in (Wrath, floor nine on the authored order),
    -- so a deep circle's stock is judged against the company that actually meets it.
    requiredPrestige = 8,
    map = {
        -- The ground of that circle. The descent picks its own ground off the floor, so this is the
        -- authored claim tests/biome_spec.lua validates, not what draws the board.
        biome = "volcanic",
        objective = {
            name = "The Card's Opener",
            layout = "colosseum_sand",
            composition = function()
                return { "character_saber_bout", "character_orc_spear_hurler" }
            end,
            -- Assassinate, not killAll: the bout ends when SABER goes down, which is both the fiction and
            -- the fix for adds.
            win = { type = "assassinate", target = "character_saber_bout" },
        },
    },
}
