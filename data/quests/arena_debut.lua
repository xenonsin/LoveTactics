-- Slot 1 of the Colosseum's ten (docs/story.md, "The Colosseum: wrath, designed"), and the prologue's
-- climax (states/prologue.lua). The first quest a new player finishes -- the fight that gives the
-- nameless survivor a name.
--
-- THE PREMISE. The Colosseum is a venue and a league; the real powers are the STABLES, houses that put
-- teams on the sand against each other. The player arrives with no house at all, which is the whole
-- point of them: the only team out there with nothing behind it.
--
-- So the debut is not a tryout, it is a mismatch sold as one. A booking house has hired a free agent
-- to open the card against the nobody, because a veteran against an unknown is a safe bet and a good
-- crowd. The free agent is Saber (data/characters/character_saber.lua), who fights for whoever books
-- her, house to house, and has done since the Perennial washed her out.
--
-- WHAT IT COSTS SABER: nothing yet. She is enjoying herself. That is deliberate -- she loves this, and
-- the line does not work unless the player sees why before it starts asking what her joy pays for.
--
-- WHY SHE SIGNS. Not because she was beaten; she has been beaten before. Because the party that did it
-- is the only outfit on the sand that is not part of the machine, and what she wants is a team that
-- can go all the way to the thing under it. `rewardCharacter` is the data path for that (the prologue
-- runs Quest.complete through completeArenaDebut, so the recruit fires there like any other reward).
--
-- THE BOUT IS THE THESIS, TAUGHT AS A BEATING. Saber carries The First Motion
-- (data/items/weapon/weapon_first_motion.lua), which hits hardest into a target at FULL health -- so
-- her opening blow on a fresh party is the largest number a new player has seen, and it lands before
-- anyone has taken a scratch. That is the exact rule the general at slot 10 inverts: Ira scales as her
-- own health falls (data/traits/trait_wrath_rising.lua), so a long trade wakes her up. The player is
-- being examined on this arithmetic nine quests early, and the tutorial for it is being hit by it.
--
-- No unique item, and it is the one slot in the ten that does not want one: the reward IS the
-- companion, and putting a trinket beside her would only compete with her.
return {
    name = "Debut on the Sand",
    description = "You have no house, no record, and an opening bout against a hired veteran. " ..
        "The odds are the entertainment.",
    difficulty = "Easy",
    sponsor = "colosseum",
    rewardGold = 60,
    rewardRep = 25,
    rewardPrestige = 1,
    requiredPrestige = 1,
    -- Bested, then kept (docs/story.md, "The other seven"). Player.recruit refuses a duplicate, so
    -- this is safe on any path that reaches Quest.complete more than once.
    rewardCharacter = "character_saber",
    map = {
        biome = "castle",
        encounters = { min = 2, max = 4 }, -- map size scales with this (models/overworld.lua)
        objective = {
            name = "The Card's Opener",
            -- Saber and one hand from the house that booked her -- a team, because everything on this
            -- sand is a team. Kept to two so a two-unit prologue party is tested and not buried; she
            -- is the bout, the other is a wall.
            composition = function() return { "character_saber", "character_bandit" } end,
            opening = "colosseum_debut_confront",
            win = { type = "killAll" },
        },
        keyCount = 0,
    },
}
