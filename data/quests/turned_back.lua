-- Slot 2 of the Bastion's ten. Every other vendor line spends this slot recruiting its companion;
-- the knight's is already sworn to the player from the prologue (data/characters/character_knight.lua),
-- so the Bastion spends it on Rowan herself -- and on the first crack in the icon.
--
-- WHO THEY ACTUALLY ARE. Sixty knights held Greywatch. When Acedia opened the gate and put the terms
-- to her garrison, forty-one took them and became her company (data/characters/character_forsworn_knight.lua).
-- NINETEEN REFUSED. They walked out with nothing -- not forsworn, not corrupted, simply out.
--
-- And the Bastion would not have them back. Nineteen knights returning with that story ends the
-- martyr, and the martyr is the only thing keeping the line manned, so the order turned its own
-- loyal men away at the door and struck them off the rolls. Fifteen years later they are taking
-- wagons on a road they used to guard, because there was nothing else left to be.
--
-- The title reads two ways and the second one is the true one: the player takes this quest thinking
-- it names men who turned back, and it names the men the Bastion turned back.
--
-- THE SIN. This is slot 8 rehearsed early and deniably -- the order weighing a hard truth against a
-- useful saint and taking the easier one, exactly as it will do again in the second vault. It
-- manufactured these bandits to protect a story, and it is now paying a knight to erase them. Nobody
-- says any of that out loud here and nobody can prove it; the player is simply given the arithmetic
-- (see data/items/utility/utility_names_he_kept.lua) and left holding it for three quests.
--
-- WHAT ROWAN DOES WITH IT. She dismisses them as deserters inventing a justification -- the line's
-- engine, the icon defended with a bad argument. Except they are not forsworn, and the accusation
-- will not quite fit, and she can hear that it doesn't. That is the crack, and she puts it there
-- herself.
--
-- The nothing-said rule (docs/story.md): no scene here may state that Acedia defected. The Road-
-- Captain gets to be bitter and oblique and no more. Slots 5, 7 and 8 are where that lands.
return {
    name = "The Ones Who Would Not",
    description = "A crew has been taking wagons on the eastern road -- too clean, too disciplined, " ..
        "and nobody killed. The Bastion wants it ended and will not say why.",
    difficulty = "Easy",
    sponsor = "bastion",
    intro = "bastion_turned_back_intro",
    outro = "bastion_turned_back_outro",
    rewardItems = { "utility_names_he_kept" },
    rewardGold = 100,
    rewardRep = 20,
    rewardPrestige = 1,
    requiredPrestige = 1,
    map = {
        biome = "forest",
        encounters = { min = 5, max = 7 },
        objective = {
            name = "The Road-Captain's Camp",
            -- The captain and his men. They fight, and that is the honest version of this slot: they
            -- are armed, desperate, and have been told for fifteen years that they do not exist. The
            -- moral weight is not that they refuse to defend themselves -- it is that they are the
            -- men who held when the icon didn't, and the party is here on the order's coin.
            composition = function(ctx)
                local list = { "character_greywatch_captain" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do
                    list[#list + 1] = "character_greywatch_refuser"
                end
                return list
            end,
            opening = "bastion_turned_back_confront",
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
