-- THE FAMILIAR'S WHISTLE: the Familiar's drop (Wrath's vampires, round 1 note: "summon your own familiar to heal
-- you, respawn on death"). Calls ONE Familiar beside you, on your side. Its bites Bleed the target and heal YOU by
-- the damage (trait_blood_courier: a whistled-up familiar carries its drink to whoever called it). If it falls it
-- comes back beside you at the start of your next turn (trait_familiars_whistle). While it is out it reserves a
-- fifth of your max mana -- the rule Vesh's Call the Lured set for a summon.
return {
    name = "Familiar's Whistle",
    description = "Summon a Familiar whose bites Bleed and heal you. It returns on your next turn if it falls.",
    flavor = "A bone whistle too high for any ear but a bat's.",
    sprite = "assets/items/ability_familiars_whistle.png",
    type = "ability",
    tags = { "summon", "beast" },
    class = "summoner",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_familiars_whistle" },
    activeAbility = {
        target = "tile",
        range = 1,
        speed = 5,
        support = true,
        reserve = { stat = "mana", percent = 0.2 },
        effect = function(fx)
            fx.summon("character_familiar", fx.tx, fx.ty)
        end,
    },
}
