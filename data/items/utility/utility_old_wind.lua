-- Ondo's bound relic (Shaman). He asks the ground for help, and it answers.
--
-- EVERY HAZARD ON THE FIELD STANDS UP. Call Spirit and Bind Spirit are the one-at-a-time reading;
-- Ancestor Mask gives spirits his hazards' element, Spirit Fetish empowers them, and Ghost-Wind lets
-- them walk through walls and feed on what is left. All four are worth more the more spirits there
-- are, and this is the only thing that makes a lot of them at once.
--
-- IT READS THE WHOLE BOARD, not just his own ground, and that is deliberate: a shaman does not own the
-- weather. A mage's firestorm and an enemy's rain are both something standing there that can be asked,
-- which is the difference between this and the Elementalist's Ninth Sigil -- Nio copies HIS workings
-- outward, Ondo wakes whatever is already present, whoever laid it.
return {
    name = "The Old Wind",
    description = "Every hazard on the field stands up as a spirit under your command.",
    flavor = "None of it was ever weather. It was simply not being spoken to.",
    sprite = "assets/items/sig_old_wind.png",
    type = "utility",
    tags = { "signature", "primal" },
    class = "mage",
    discipline = "shaman",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 7,
        cost = { stat = "mana", amount = 16 },
        description = "Raises a spirit from every hazard standing on the field.",
        unlock = { event = "cast", count = 3, text = "Cast 3 times" },
        effect = function(fx)
            -- Snapshot the ground first: a summon lands ON a tile and the list would otherwise grow
            -- under the loop that is walking it.
            local ground = {}
            for _, h in ipairs((fx.combat and fx.combat.hazards) or {}) do
                if h.alive then ground[#ground + 1] = { x = h.x, y = h.y } end
            end
            for _, at in ipairs(ground) do
                local tile = fx.openTileNear(at.x, at.y)
                if tile then fx.summon("character_wolfsong_spirit", tile.x, tile.y) end
            end
        end,
    },
    -- the field's hazards stand up and take your side
    bonus = { magicDamage = 2 },
}
