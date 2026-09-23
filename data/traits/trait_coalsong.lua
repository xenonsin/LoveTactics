-- COALSONG: the Matriarch's cry with the player's name on it. Whatever the bearer Taunts also catches
-- fire.
--
-- IT IS HER WEAPON, FACTORED. The Wanting lands Taunt and Burn together in one cast
-- (data/items/weapon/weapon_the_wanting.lua), and what that couple MEANS is the Lust circle's whole
-- sentence about fire: you are compelled to come, and the coming is what costs you. This hands the
-- player the coupling rather than the cast -- so it fires on whatever taunt the bearer already owns
-- and never on one it does not.
--
-- WHICH MAKES IT A PAIR AND NOT A TIER. On a body with no taunt in its kit this is a blank charm in a
-- grid cell -- a dead item, on purpose. On a Champion it is the difference between drawing the field
-- onto you and drawing a burning field onto you, and it pays best exactly where a taunt already pays
-- best: Shout takes a whole diamond, so one cast lights everything in it. The player assembles that;
-- the item does not hand it over.
--
-- SO IT SHELVES AT THE CHAMPION, where the taunts are. "Draws the whole field onto you. Taunts pull
-- attacks your way" (data/classes/champion.lua) -- three of the game's seven taunt deliverers are on
-- that ladder, and shelving the payoff beside them is how the synergy is findable rather than a thing
-- you have to already know.
--
-- AND IT PAYS OFF TWO PIECES THAT HAD NOTHING. armor_crowds_due and armor_standing_debt taunt every
-- foe around their wearer, and until the stamp moved into the status they pointed at nobody and
-- redirected exactly zero blows. They work now, and this is what makes a Sentinel who took that armour
-- for the redirect suddenly interested in it for the fire as well.
--
-- NO COOLDOWN, unlike trait_executioners_eye, which it otherwise copies verb for verb. The Eye rides
-- on stun and freeze -- hard control the bearer gets for free off any weapon proc -- and needs pacing.
-- A taunt is always a deliberate cast with a cost already paid, so the pacing is the ability's, and a
-- cooldown on top would mean a Shout that lit two of the four foes it caught and left the player
-- guessing which two.
--
-- NO RUNAWAY. Applying Burn re-enters Trait.onStatusApplied with the bearer as applier again, and the
-- id gate below declines it -- Burn is not Taunt. Stated because the hook is genuinely re-entrant and
-- the guard is one line that looks like a filter.
return {
    name = "Coalsong",
    description = "Foes you taunt catch fire.",
    onStatusApplied = function(ctx)
        if ctx.role ~= "applier" then return end
        if (ctx.status and ctx.status.id) ~= "status_taunt" then return end
        local foe = ctx.recipient
        if not foe or not foe.alive or foe.side == ctx.unit.side then return end
        ctx.applyStatus(foe, "status_burn")
    end,
}
