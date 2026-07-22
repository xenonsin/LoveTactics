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
-- can go all the way to the thing under it. `rewardCharacter` is the data path for that -- Quest.complete
-- recruits her the moment the bout is won. But her ASKING is a scene, not a payout: the victory outro
-- (the Gatekeeper) has her defer it, and `followUp` below walks the party off the sand into a short
-- overworld leg where she catches them past the gate and puts the question. The join banner is held
-- across the outro (states/game.lua defers it whenever a quest has a followUp) so it lands in that
-- meeting rather than over the arena -- see data/conversations/arena_saber_joins.lua.
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
    -- The victory scene, played over the frozen final frame before the follow-up leg opens (states/game
    -- .lua's objective-win path). Saber is already recruited by the time it runs -- Quest.complete grants
    -- `rewardCharacter` before the outro fires -- but here she only acknowledges the loss and tells the
    -- party to wait for her past the gate, and the Guild envoy opens the board on the rest of the game.
    -- Her actual joining is the followUp meeting below; the banner is held for it (deferJoins).
    outro = "prologue_victory",
    -- A short overworld leg played straight after the outro, before the hub: the party walks off the
    -- sand and Saber catches them on the road out. It is an INLINE quest table (never on the Quest
    -- Board -- only files under data/quests/ are listed), run as a scripted traversal -- states/game.lua
    -- launches it with an onComplete that returns to the hub, so it pays out nothing of its own and
    -- cannot be abandoned (`scripted` hides the Back button). Its single objective is a non-combat
    -- `meet`: reaching the gate plays the join scene and ends the leg. See states/game.lua.
    followUp = {
        name = "Off the Sand",
        map = {
            biome = "castle",
            scripted = true, -- a cutscene walk, not a board quest: no Back button, no abandon
            -- One quiet breather on the way out, then the gate. No random bouts -- the climax was the
            -- bout; this leg is the walk down from it.
            encounters = {
                min = 1, max = 1,
                always = { { id = "encounter_rest" } },
            },
            objective = {
                name = "The Gate Out",
                -- A non-combat meeting: stepping onto the objective plays the scene and completes the
                -- leg instead of dropping into a fight (states/game.lua's meet branch). Saber is already
                -- on the roster, so this only stages the ask; the held join banner folds onto the scene.
                meet = true,
                conversation = "arena_saber_joins",
            },
            keyCount = 0,
        },
    },
    map = {
        biome = "castle",
        -- The walk to the tunnel mouth is the undercard, not a maze to survive. A curated stop list
        -- rather than a bare roll: one narrative scene that teaches the bout's thesis before the bout
        -- (the mismatch, sold as entertainment), a couple of non-combat beats -- a found cache and a
        -- moment to breathe before the veteran -- and a short warm-up. `always` pins the authored
        -- three; min/max tops the card up with a scuffle or two from the castle pool (beast bouts are
        -- ordinary arena fare). Map size scales with this AND the biome's density now (models/overworld.lua),
        -- so a tight castle no longer sprawls into an empty warren for a handful of stops.
        encounters = {
            min = 5, max = 6,
            always = {
                -- The concourse scene: a booking man prices the nobody. Non-combat, and the one
                -- narrative stop on the card (data/conversations/arena_debut_event.lua).
                { id = "encounter_event", conversation = "arena_debut_event" },
                -- An unclaimed kit from a bout that never happened -- a small find on the way in.
                { id = "encounter_treasure" },
                -- A last breath before the veteran, so the debut is fought fresh (Player.restore).
                { id = "encounter_rest" },
            },
        },
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
