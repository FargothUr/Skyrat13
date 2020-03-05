/mob/living/simple_animal/hostile/megafauna
	weather_immunities = list("lava","ash", "snow")



/mob/living/simple_animal/hostile/megafauna/rogueprocess
	name = "Rogue Process"
	desc = "Once an experimental ripley carrying an advanced mining AI, now it's out for blood."
	health = 2500
	maxHealth = 2500
	attacktext = "drills"
	attack_sound = 'sound/weapons/drill.ogg'
	icon = 'modular_skyrat/icons/mob/lavaland/rogue.dmi'
	icon_state = "rogue"
	icon_living = "rogue"
	icon_dead = "rogue-broken"
	friendly = "pokes"
	speak_emote = list("screeches")
	armour_penetration = 75
	melee_damage_lower = 30
	melee_damage_upper = 30
	speed = 1
	move_to_delay = 18
	ranged_cooldown_time = 75
	ranged = 1
	del_on_death = 0
	crusher_loot = list(/obj/item/borg/upgrade/modkit/plasma, /obj/item/crusher_trophy/brokentech, /obj/item/twohanded/rogue)
	loot = list(/obj/item/borg/upgrade/modkit/plasma, /obj/item/twohanded/rogue)
	deathmessage = "sparkles and emits corrupted screams in agony, falling defeated on the ground."
	death_sound = 'sound/mecha/critdestr.ogg'
	anger_modifier = 0
	do_footstep = TRUE
	mob_biotypes = MOB_ROBOTIC
	wander = FALSE
	movement_type = GROUND

/obj/item/gps/internal/rogueprocess
	icon_state = null
	gpstag = "Corrupted Signal"
	desc = "It's full of ransomware."
	invisibility = 100

/obj/item/projectile/plasma/rogue
	speed = 2
	range = 21
	color = "#FF0000"

/mob/living/simple_animal/hostile/megafauna/rogueprocess/Initialize()
	. = ..()
	internal = new /obj/item/gps/internal/rogueprocess(src)

/mob/living/simple_animal/hostile/megafauna/rogueprocess/Life()
	. = ..()
	anger_modifier = round(CLAMP(((maxHealth - health) / 42),0,60))
	move_to_delay = CLAMP(round((src.health/src.maxHealth) * 10), 3, 18)

/mob/living/simple_animal/hostile/megafauna/rogueprocess/OpenFire(target)
	ranged_cooldown = world.time + (ranged_cooldown_time - anger_modifier) //Ranged cooldown will always be at least 15
	if(anger_modifier < 30)
		if(prob(50))
			INVOKE_ASYNC(src, .proc/plasmashot, target)
			INVOKE_ASYNC(src, .proc/spawnminions, target)
		else
			INVOKE_ASYNC(src, .proc/shockwave, src.dir, 7)
	if(anger_modifier >= 30 && anger_modifier <40)
		if(prob(50))
			INVOKE_ASYNC(src, .proc/plasmaburst, target)
		else
			INVOKE_ASYNC(src, .proc/shockwave, src.dir, 10)
	if(anger_modifier >= 30 && anger_modifier <40)
		if(prob(50))
			INVOKE_ASYNC(src, .proc/plasmacrazy, target)
		else
			INVOKE_ASYNC(src, .proc/shockwave, NORTH, 15)
			INVOKE_ASYNC(src, .proc/shockwave, SOUTH, 15)
			INVOKE_ASYNC(src, .proc/shockwave, WEST, 15)
			INVOKE_ASYNC(src, .proc/shockwave, EAST, 15)
	if(anger_modifier >= 50)
		if(prob(50))
			INVOKE_ASYNC(src, .proc/plasmacrazy, target)
			INVOKE_ASYNC(src, .proc/shockwave, src.dir, 15)
		else
			INVOKE_ASYNC(src, .proc/shockwave, NORTH, 15)
			INVOKE_ASYNC(src, .proc/shockwave, SOUTH, 15)
			INVOKE_ASYNC(src, .proc/shockwave, WEST, 15)
			INVOKE_ASYNC(src, .proc/shockwave, EAST, 15)
			INVOKE_ASYNC(src, .proc/shockwave, NORTHEAST, 15)
			INVOKE_ASYNC(src, .proc/shockwave, NORTHWEST, 15)
			INVOKE_ASYNC(src, .proc/shockwave, SOUTHWEST, 15)
			INVOKE_ASYNC(src, .proc/shockwave, SOUTHEAST, 15)

/mob/living/simple_animal/hostile/megafauna/rogueprocess/AttackingTarget(target)
	say("YOU ARE PATHETIC.")
	if(prob(25))
		if(prob(50))
			knockdown()
		else
			shockwave(src.dir)
	else
		..()

/mob/living/simple_animal/hostile/megafauna/rogueprocess/Move()
	. = ..()
	playsound(src.loc, 'sound/mecha/mechmove01.ogg', 200, 1, 2, 1)

/mob/living/simple_animal/hostile/megafauna/rogueprocess/Bump(atom/A)
	. = ..()
	if(isturf(A) || isobj(A) && A.density)
		A.ex_act(EXPLODE_HEAVY)
		DestroySurroundings()

/mob/living/simple_animal/hostile/megafauna/rogueprocess/proc/plasmashot(atom/target)
	var/list/theline = getline(src, target)
	if(theline.len > 2)
		visible_message("<span class='boldwarning'>[src] raises it's plasma cutter!</span>")
		sleep(5)
		say("I CLEANSE THE WORLD WITH MY CUTTER.")
		var/turf/T = get_turf(src)
		var/obj/item/projectile/P = new /obj/item/projectile/plasma/rogue(T)
		var/turf/startloc = T
		playsound(src, 'sound/weapons/laser.ogg', 100, TRUE)
		P.starting = startloc
		P.firer = src
		P.fired_from = src
		P.yo = target.y - startloc.y
		P.xo = target.x - startloc.x
		P.original = target
		P.preparePixelProjectile(target, src)
		P.fire()
	else
		visible_message("<span class='boldwarning'>[src] raises it's drill!</span>")
		say("YOUR WEAK MELEES WON'T DENT ME.")
		sleep(5)
		SEND_SIGNAL(src, COMSIG_HOSTILE_ATTACKINGTARGET, target)
		in_melee = TRUE
		target.attack_animal(src)

/mob/living/simple_animal/hostile/megafauna/rogueprocess/proc/plasmaburst(atom/target)
	var/list/theline = getline(src, target)
	if(theline.len > 2)
		visible_message("<span class='boldwarning'>[src] raises it's tri-shot plasma cutter!</span>")
		say("MY AIM IS PRECISE AND MY WILL IS PLASTEEL.")
		sleep(15)
		for(var/i = 0, i < 2, i++)
			var/obj/item/projectile/P = new /obj/item/projectile/plasma/rogue(T)
			var/turf/startloc = get_turf(src)
			playsound(src, 'sound/weapons/laser.ogg', 100, TRUE)
			P.starting = startloc
			P.firer = src
			P.fired_from = src
			P.yo = target.y - startloc.y
			P.xo = target.x - startloc.x
			P.original = target
			P.preparePixelProjectile(target.loc, src)
			switch(i)
				if(1)
					P.angle += 30
				if(2)
					P.angle -= 30
			P.fire()
	else
		visible_message("<span class='boldwarning'>[src] raises it's drill!</span>")
		say("YOUR ATTACKS BARELY AFFECT ME.")
		sleep(5)
		SEND_SIGNAL(src, COMSIG_HOSTILE_ATTACKINGTARGET, target)
		in_melee = TRUE
		target.attack_animal(src)

/mob/living/simple_animal/hostile/megafauna/rogueprocess/proc/plasmacrazy(atom/target)
	var/list/theline = getline(src, target)
	if(theline.len > 2)
		visible_message("<span class='boldwarning'>[src] raises FOUR tri-shot plasma cutters! What the heck?!</span>")
		say("I AM UNBREAKABLE.")
		sleep(15)
		say("WEAK!!! STUPID!!! ORGANIC!!!")
		for(var/angle = 0, i < 360, i += 30)
			sleep(5)
			var/obj/item/projectile/P = new /obj/item/projectile/plasma/rogue(T)
			var/turf/startloc = get_turf(src)
			playsound(src, 'sound/weapons/laser.ogg', 100, TRUE)
			P.starting = startloc
			P.firer = src
			P.fired_from = src
			P.yo = target.y - startloc.y
			P.xo = target.x - startloc.x
			P.original = target
			P.preparePixelProjectile(target.loc, src)
			P.angle += i
			P.fire()
	else
		visible_message("<span class='boldwarning'>[src] raises it's drill!</span>")
		sleep(5)
		SEND_SIGNAL(src, COMSIG_HOSTILE_ATTACKINGTARGET, target)
		in_melee = TRUE
		target.attack_animal(src)

/mob/living/simple_animal/hostile/megafauna/rogueprocess/proc/knockdown()
	visible_message("<span class='boldwarning'>[src] smashes into the ground!</span>")
	playsound(src,'sound/misc/crunch.ogg', 200, 1)
	var/list/hit_things = list()
	sleep(10)
	for(var/turf/T in oview(2, src))
		new /obj/effect/temp_visual/small_smoke/halfsecond(T)
		for(var/mob/living/L in T.contents)
			if(L != src && !(L in hit_things))
				var/throwtarget = get_edge_target_turf(src, get_dir(src, L))
				L.safe_throw_at(throwtarget, 10, 1, src)
				L.Stun(20)
				L.adjustBruteLoss(50)

/mob/living/simple_animal/hostile/megafauna/rogueprocess/proc/spawnminion()
	visible_message("<span class='boldwarning'>[src] opens his back and a swarmer comes out of it!</span>")


/mob/living/simple_animal/hostile/megafauna/rogueprocess/proc/shockwave(direction, range)
	visible_message("<span class='boldwarning'>[src] smashes the ground in a general direction!!</span>")
	playsound(src,'sound/misc/crunch.ogg', 200, 1)
	sleep(10)
	var/list/hit_things = list()
	var/turf/T = get_turf(get_step(src, src.dir))
	var/ogdir = direction
	var/turf/otherT = get_step(T, turn(ogdir, 90))
	var/turf/otherT2 = get_step(T, turn(ogdir, -90))
	for(var/i = 0, i<range, i++)
		new /obj/effect/temp_visual/small_smoke/halfsecond(T)
		new /obj/effect/temp_visual/small_smoke/halfsecond(otherT)
		new /obj/effect/temp_visual/small_smoke/halfsecond(otherT2)
		for(var/mob/living/L in T.contents)
			if(L != src && !(L in hit_things))
				var/throwtarget = get_edge_target_turf(T, get_dir(T, L))
				L.safe_throw_at(throwtarget, 5, 1, src)
				L.Stun(10)
				L.adjustBruteLoss(25)
		for(var/mob/living/L in otherT.contents)
			if(L != src && !(L in hit_things))
				var/throwtarget = get_edge_target_turf(otherT, get_dir(otherT, L))
				L.safe_throw_at(throwtarget, 5, 1, src)
				L.Stun(10)
				L.adjustBruteLoss(25)
		for(var/mob/living/L in otherT2.contents)
			if(L != src && !(L in hit_things))
				var/throwtarget = get_edge_target_turf(otherT2, get_dir(otherT2, L))
				L.safe_throw_at(throwtarget, 5, 1, src)
				L.Stun(10)
				L.adjustBruteLoss(25)
		T = get_step(T, ogdir)
		otherT = get_step(otherT, ogdir)
		otherT2 = get_step(otherT2, ogdir)
		sleep(2)

//loot
/obj/item/twohanded/rogue
	name = "Rogue's Drill"
	desc = "A drill coupled with an internal mechanism that produces shockwaves on demand. Serves as a very robust melee."
	force = 0
	force_wielded = 25
	force_unwielded = 0
	icon = 'modular_skyrat/icons/obj/mining.dmi'
	icon_state = "roguedrill"
	lefthand_file = 'modular_skyrat/icons/mob/inhands/equipment/mining_lefthand.dmi'
	righthand_file = 'modular_skyrat/icons/mob/inhands/equipment/mining_righthand.dmi'
	item_state = "roguedrill"
	w_class = WEIGHT_CLASS_BULKY
	tool_behaviour = TOOL_MINING
	toolspeed = 0.05
	slot_flags = ITEM_SLOT_BELT
	custom_materials = list(/datum/material/diamond=2000)
	usesound = 'sound/weapons/drill.ogg'
	hitsound = 'sound/weapons/drill.ogg'
	attack_verb = list("drilled")
	var/cooldowntime
	var/range = 7
	var/cooldown = 50

/obj/item/twohanded/rogue/attack(atom/A, mob/living/carbon/human/user)
	. = ..()
	if(isliving(A))
		playsound(src,'sound/misc/crunch.ogg', 200, 1)
		var/mob/living/M = A
		if(ishuman(M))
			M.Knockdown(25, override_stamdmg = 0)
		M.adjustStaminaLoss(25)
		M.drop_all_held_items()

/obj/item/twohanded/rogue/afterattack(atom/target, mob/living/user, proximity_flag)
	. = ..()
	if(wielded)
		if(!proximity_flag)
			if(cooldowntime < world.time)
				cooldowntime = world.time + cooldown
				playsound(src,'sound/misc/crunch.ogg', 200, 1)
				var/list/hit_things = list()
				var/turf/T = get_turf(get_step(user, user.dir))
				var/ogdir = user.dir
				var/turf/otherT = get_step(T, turn(ogdir, 90))
				var/turf/otherT2 = get_step(T, turn(ogdir, -90))
				for(var/i = 0, i < range, i++)
					new /obj/effect/temp_visual/small_smoke/halfsecond(T)
					new /obj/effect/temp_visual/small_smoke/halfsecond(otherT)
					new /obj/effect/temp_visual/small_smoke/halfsecond(otherT2)
					for(var/mob/living/L in T.contents)
						if(L != src && !(L in hit_things))
							L.Stun(20)
							L.adjustBruteLoss(10)
					for(var/mob/living/L in otherT.contents)
						if(L != src && !(L in hit_things))
							L.Stun(20)
							L.adjustBruteLoss(10)
					for(var/mob/living/L in otherT2.contents)
						if(L != src && !(L in hit_things))
							L.Stun(20)
							L.adjustBruteLoss(10)
					if(ismineralturf(T))
						var/turf/closed/mineral/M = T
						M.gets_drilled(user)
					if(ismineralturf(otherT))
						var/turf/closed/mineral/M = otherT
						M.gets_drilled(user)
					if(ismineralturf(otherT2))
						var/turf/closed/mineral/M = otherT2
						M.gets_drilled(user)
					T = get_step(T, ogdir)
					otherT = get_step(otherT, ogdir)
					otherT2 = get_step(otherT2, ogdir)
					sleep(2)

//helpers
/mob/living/simple_animal/hostile/swarmer/ai/ranged_combat/rogue
	name = "Rogue's Elite Guard"
	desc = "A loyal spawn of their robotic master."
	health = 150

/mob/living/simple_animal/hostile/swarmer/ai/melee_combat/rogue
	name = "Rogue's Guard"
	desc = "A loyal spawn of their robotic master."
	health = 100