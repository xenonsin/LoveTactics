-- Lifted off Aurea's body, and it kept her rule (docs/story.md, "The Undercroft"): the Kingsblood
-- Dagger's foreshadow -- greed "lifts the kit out of your hands mid-fight" -- made a relic. Carry the
-- Purse and you gild your foes and take their gear for your own: you become the thing you killed, unable
-- to stop taking, the shape every one of the seven relics takes (compare
-- data/items/utility/utility_codex_unanswered.lua).
--
-- A purse that is never full -- greed's own vessel, and a TYPE of its own beside the armor, spear, mail,
-- reliquary, bow, mirror and tome of the others.
--
-- GREED'S RULE IS AN ABILITY, NOT A TRAIT (docs/story.md's engine table: "an ability whose effect calls
-- fx.steal(fx.target)" -- no new engine, see ability_pickpocket). So the Purse carries the Golden Touch as
-- an ACTIVE rather than a passive: worn, it is how you take. The whole GOLD ECONOMY the chapter designs --
-- gold as ward, action-cost and board-loot, and the bankruptcy-triggered two-phase transform -- is a
-- bespoke finale subsystem, deferred new work; the bare take-a-thing is what ships.
--
-- No `class`, no `price`, `noSteal`: you took it off her, and nothing takes it back. The FLAVOR carries
-- this general's fragment of the Gate Below's location (docs/item-text.md: story, not a rule). The Gate is
-- keyed off the QUEST finished, never off this item (questGate in models/quest.lua).
return {
    name = "Bottomless Purse",
    description = "The Golden Touch: strike an adjacent foe and lift an item off it into your own hands.",
    flavor = "Aurea's purse, and it has never once been full. Stitched inside the lip: " ..
        "\"beneath the vault that was never full\".",
    sprite = "assets/items/bottomless_purse.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true, -- you took it off her; nothing takes it back
    bonus = { defense = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } },
    activeAbility = {
        description = "Lift an item off an adjacent foe and take it for your own.",
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            fx.steal(fx.target) -- the Golden Touch, fantasy-skinned: what she stays alive on
        end,
    },
}
