//CITADEL EDIT
GLOBAL_LIST_EMPTY(objectives)
//END EDIT

/datum/objective
	var/datum/mind/owner				//The primary owner of the objective. !!SOMEWHAT DEPRECATED!! Prefer using 'team' for new code.
	var/datum/team/team					//An alternative to 'owner': a team. Use this when writing new code.
	var/name = "generic objective" 		//Name for admin prompts
	var/explanation_text = "Nothing"	//What that person is supposed to do.
	var/team_explanation_text			//For when there are multiple owners.
	var/datum/mind/target = null		//If they are focused on a particular person.
	var/target_amount = FALSE			//If they are focused on a particular number. Steal objectives have their own counter.
	var/completed = FALSE				//currently only used for custom objectives.
	var/completable = TRUE				//Whether this objective shows greentext when completed
	var/martyr_compatible = FALSE		//If the objective is compatible with martyr objective, i.e. if you can still do it while dead.

/datum/objective/New(var/text)
	GLOB.objectives += src // CITADEL EDIT FOR CRYOPODS
	if(text)
		explanation_text = text

/datum/objective/Destroy(force, ...)
	GLOB.objectives -= src
	if(owner)
		for(var/datum/antagonist/A in owner.antag_datums)
			A.objectives -= src
	if(team)
		team.objectives -= src
	. = ..()

/datum/objective/proc/get_owners() // Combine owner and team into a single list.
	. = (team && team.members) ? team.members.Copy() : list()
	if(owner)
		. += owner

/datum/objective/proc/admin_edit(mob/admin)
	return

//Shared by few objective types
/datum/objective/proc/admin_simple_target_pick(mob/admin)
	var/list/possible_targets = list("Free objective")
	var/def_value
	for(var/datum/mind/possible_target in SSticker.minds)
		if ((possible_target != src) && ishuman(possible_target.current))
			possible_targets += possible_target.current


	if(target && target.current)
		def_value = target.current

	var/mob/new_target = input(admin,"Select target:", "Objective target", def_value) as null|anything in possible_targets
	if (!new_target)
		return

	if (new_target == "Free objective")
		target = null
	else
		target = new_target.mind

	update_explanation_text()

/datum/objective/proc/considered_escaped(datum/mind/M)
	if(!considered_alive(M))
		return FALSE
	if(M.force_escaped)
		return TRUE
	if(SSticker.force_ending || SSticker.mode.station_was_nuked) // Just let them win.
		return TRUE
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return FALSE
	var/turf/location = get_turf(M.current)
	if(!location || istype(location, /turf/open/floor/plasteel/shuttle/red) || istype(location, /turf/open/floor/mineral/plastitanium/red/brig)) // Fails if they are in the shuttle brig
		return FALSE
	return location.onCentCom() || location.onSyndieBase()

/datum/objective/proc/check_completion()
	return completed

/datum/objective/proc/is_unique_objective(possible_target)
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		for(var/datum/objective/O in M.get_all_objectives()) //This scope is debatable, probably should be passed in by caller.
			if(istype(O, type) && O.get_target() == possible_target)
				return FALSE
	return TRUE

/datum/objective/proc/get_target()
	return target

/datum/objective/proc/get_crewmember_minds()
	. = list()
	for(var/V in GLOB.data_core.locked)
		var/datum/data/record/R = V
		var/datum/mind/M = R.fields["mindref"]
		if(M)
			. += M

/datum/objective/proc/find_target(dupe_search_range, blacklist)
	var/list/datum/mind/owners = get_owners()
	if(!dupe_search_range)
		dupe_search_range = get_owners()
	var/list/possible_targets = list()
	var/try_target_late_joiners = FALSE
	for(var/I in owners)
		var/datum/mind/O = I
		if(O.late_joiner)
			try_target_late_joiners = TRUE
	for(var/datum/mind/possible_target in get_crewmember_minds())
		if(!(possible_target in owners) && ishuman(possible_target.current) && (possible_target.current.stat != DEAD) && is_unique_objective(possible_target))
			if(!(possible_target in blacklist))
				possible_targets += possible_target
	if(try_target_late_joiners)
		var/list/all_possible_targets = possible_targets.Copy()
		for(var/I in all_possible_targets)
			var/datum/mind/PT = I
			if(!PT.late_joiner)
				possible_targets -= PT
		if(!possible_targets.len)
			possible_targets = all_possible_targets
	if(possible_targets.len > 0)
		target = pick(possible_targets)
	else
		target = null//we'd rather have no target than an invalid one // CITADEL EDIT
	update_explanation_text()
	return target

/datum/objective/proc/find_target_by_role(role, role_type=0, invert=0)//Option sets either to check assigned role or special role. Default to assigned., invert inverts the check, eg: "Don't choose a Ling"
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/possible_target in get_crewmember_minds())
		if(!(possible_target in owners) && ishuman(possible_target.current))
			var/is_role = 0
			if(role_type)
				if(possible_target.special_role == role)
					is_role++
			else
				if(possible_target.assigned_role == role)
					is_role++

			if(invert)
				if(is_role)
					continue
				target = possible_target
				break
			else if(is_role)
				target = possible_target
				break

	update_explanation_text()

/datum/objective/proc/update_explanation_text()
	if(team_explanation_text && LAZYLEN(get_owners()) > 1)
		explanation_text = team_explanation_text

/datum/objective/proc/give_special_equipment(special_equipment)
	var/datum/mind/receiver = pick(get_owners())
	if(receiver && receiver.current)
		if(ishuman(receiver.current))
			var/mob/living/carbon/human/H = receiver.current
			var/list/slots = list("backpack" = SLOT_IN_BACKPACK)
			for(var/eq_path in special_equipment)
				var/obj/O = new eq_path
				H.equip_in_one_of_slots(O, slots)

/datum/objective/assassinate
	name = "assasinate"
	var/target_role_type=0
	martyr_compatible = 1

/datum/objective/assassinate/find_target_by_role(role, role_type=0, invert=0)
	if(!invert)
		target_role_type = role_type
	..()
	return target

/datum/objective/assassinate/check_completion()
	return !considered_alive(target) || considered_afk(target)

/datum/objective/assassinate/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Assassinate [target.name], the [!target_role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"

/datum/objective/assassinate/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/assassinate/once
	name = "kill once"
	var/won = FALSE

/datum/objective/assassinate/once/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Kill [target.name], the [!target_role_type ? target.assigned_role : target.special_role]. You only need to kill them once; if they come back, you've still succeeded."
		START_PROCESSING(SSprocessing,src)
	else
		explanation_text = "Free Objective"

/datum/objective/assassinate/once/check_completion()
	return won || ..()

/datum/objective/assassinate/once/process()
	won = check_completion()
	if(won)
		STOP_PROCESSING(SSprocessing,src)

/datum/objective/assassinate/internal
	var/stolen = 0 		//Have we already eliminated this target?

/datum/objective/assassinate/internal/update_explanation_text()
	..()
	if(target && !target.current)
		explanation_text = "Assassinate [target.name], who was obliterated"

/datum/objective/mutiny
	name = "mutiny"
	var/target_role_type=0
	martyr_compatible = 1

/datum/objective/mutiny/find_target_by_role(role, role_type=0,invert=0)
	if(!invert)
		target_role_type = role_type
	..()
	return target

/datum/objective/mutiny/check_completion()
	if(!target || !considered_alive(target) || considered_afk(target))
		return TRUE
	var/turf/T = get_turf(target.current)
	return !T || !is_station_level(T.z)

/datum/objective/mutiny/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Assassinate or exile [target.name], the [!target_role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"

/datum/objective/maroon
	name = "maroon"
	var/target_role_type=0
	martyr_compatible = 1

/datum/objective/maroon/find_target_by_role(role, role_type=0, invert=0)
	if(!invert)
		target_role_type = role_type
	..()
	return target

/datum/objective/maroon/check_completion()
	return !target || !considered_alive(target) || (!target.current.onCentCom() && !target.current.onSyndieBase())

/datum/objective/maroon/update_explanation_text()
	if(target && target.current)
		explanation_text = "Prevent [target.name], the [!target_role_type ? target.assigned_role : target.special_role], from escaping alive."
	else
		explanation_text = "Free Objective"

/datum/objective/maroon/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/debrain
	name = "debrain"
	var/target_role_type=0

/datum/objective/debrain/find_target_by_role(role, role_type=0, invert=0)
	if(!invert)
		target_role_type = role_type
	..()
	return target

/datum/objective/debrain/check_completion()
	if(!target)//If it's a free objective.
		return TRUE
	if(!target.current || !isbrain(target.current))
		return FALSE
	var/atom/A = target.current
	var/list/datum/mind/owners = get_owners()

	while(A.loc) // Check to see if the brainmob is on our person
		A = A.loc
		for(var/datum/mind/M in owners)
			if(M.current && M.current.stat != DEAD && A == M.current)
				return TRUE
	return FALSE

/datum/objective/debrain/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Steal the brain of [target.name], the [!target_role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"

/datum/objective/debrain/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/protect//The opposite of killing a dude.
	name = "protect"
	martyr_compatible = 1
	var/target_role_type = 0
	var/human_check = TRUE

/datum/objective/protect/find_target_by_role(role, role_type=0, invert=0)
	if(!invert)
		target_role_type = role_type
	..()
	return target

/datum/objective/protect/check_completion()
	return !target || considered_alive(target, enforce_human = human_check)

/datum/objective/protect/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Protect [target.name], the [!target_role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"

/datum/objective/protect/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/protect/nonhuman
	name = "protect nonhuman"
	human_check = FALSE

/datum/objective/hijack
	name = "hijack"
	explanation_text = "Hijack the emergency shuttle by hacking its navigational protocols through the control console (alt click emergency shuttle console)."
	team_explanation_text = "Hijack the emergency shuttle by hacking its navigational protocols through the control console (alt click emergency shuttle console). Leave no team member behind."
	martyr_compatible = 0 //Technically you won't get both anyway.
	/// Overrides the hijack speed of any antagonist datum it is on ONLY, no other datums are impacted.
	var/hijack_speed_override = 1

/datum/objective/hijack/check_completion() // Requires all owners to escape.
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return FALSE
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!considered_alive(M) || !SSshuttle.emergency.shuttle_areas[get_area(M.current)])
			return FALSE
	return SSshuttle.emergency.is_hijacked()

/datum/objective/block
	name = "no organics on shuttle"
	explanation_text = "Do not allow any organic lifeforms to escape on the shuttle alive."
	martyr_compatible = 1

/datum/objective/block/check_completion()
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return TRUE
	for(var/mob/living/player in GLOB.player_list)
		if(player.mind && player.stat != DEAD && !issilicon(player))
			if(get_area(player) in SSshuttle.emergency.shuttle_areas)
				return FALSE
	return TRUE

/datum/objective/purge
	name = "no mutants on shuttle"
	explanation_text = "Ensure no mutant humanoid species are present aboard the escape shuttle."
	martyr_compatible = 1

/datum/objective/purge/check_completion()
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return TRUE
	for(var/mob/living/player in GLOB.player_list)
		if((get_area(player) in SSshuttle.emergency.shuttle_areas) && player.mind && player.stat != DEAD && ishuman(player))
			var/mob/living/carbon/human/H = player
			if(H.dna.species.id != "human")
				return FALSE
	return TRUE

/datum/objective/robot_army
	name = "robot army"
	explanation_text = "Have at least eight active cyborgs synced to you."
	martyr_compatible = 0

/datum/objective/robot_army/check_completion()
	var/counter = 0
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!M.current || !isAI(M.current))
			continue
		var/mob/living/silicon/ai/A = M.current
		for(var/mob/living/silicon/robot/R in A.connected_robots)
			if(R.stat != DEAD)
				counter++
	return counter >= 8

/datum/objective/escape
	name = "escape"
	explanation_text = "Escape on the shuttle or an escape pod alive and without being in custody."
	team_explanation_text = "Have all members of your team escape on a shuttle or pod alive, without being in custody."

/datum/objective/escape/check_completion()
	// Require all owners escape safely.
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!considered_escaped(M))
			return FALSE
	return TRUE

/datum/objective/breakout
	name = "breakout"
	martyr_compatible = 1
	var/target_role_type = 0
	var/human_check = TRUE

/datum/objective/breakout/check_completion()
	return !target || considered_escaped(target)

/datum/objective/breakout/find_target_by_role(role, role_type=0, invert=0)
	if(!invert)
		target_role_type = role_type
	..()
	return target

/datum/objective/breakout/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Make sure [target.name], the [!target_role_type ? target.assigned_role : target.special_role] escapes on the shuttle or an escape pod alive and without being in custody."
	else
		explanation_text = "Free Objective"

/datum/objective/escape/escape_with_identity
	name = "escape with identity"
	var/target_real_name // Has to be stored because the target's real_name can change over the course of the round
	var/target_missing_id

/datum/objective/escape/escape_with_identity/find_target()
	target = ..()
	update_explanation_text()

/datum/objective/escape/escape_with_identity/update_explanation_text()
	if(target && target.current)
		target_real_name = target.current.real_name
		explanation_text = "Escape on the shuttle or an escape pod with the identity of [target_real_name], the [target.assigned_role]"
		var/mob/living/carbon/human/H
		if(ishuman(target.current))
			H = target.current
		if(H && H.get_id_name() != target_real_name)
			target_missing_id = 1
		else
			explanation_text += " while wearing their identification card"
		explanation_text += "." //Proper punctuation is important!

	else
		explanation_text = "Free Objective."

/datum/objective/escape/escape_with_identity/check_completion()
	if(!target || !target_real_name)
		return TRUE
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!ishuman(M.current) || !considered_escaped(M))
			continue
		var/mob/living/carbon/human/H = M.current
		if(H.dna.real_name == target_real_name && (H.get_id_name() == target_real_name || target_missing_id))
			return TRUE
	return FALSE

/datum/objective/escape/escape_with_identity/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/survive
	name = "survive"
	explanation_text = "Stay alive until the end."

/datum/objective/survive/check_completion()
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!considered_alive(M))
			return FALSE
	return TRUE

/datum/objective/survive/exist //Like survive, but works for silicons and zombies and such.
	name = "survive nonhuman"

/datum/objective/survive/exist/check_completion()
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!considered_alive(M, FALSE))
			return FALSE
	return TRUE

/datum/objective/martyr
	name = "martyr"
	explanation_text = "Die a glorious death."

/datum/objective/martyr/check_completion()
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(considered_alive(M))
			return FALSE
		if(M.current?.suiciding) //killing yourself ISN'T glorious.
			return FALSE
	return TRUE

/datum/objective/nuclear
	name = "nuclear"
	explanation_text = "Destroy the station with a nuclear device."
	martyr_compatible = 1

/datum/objective/nuclear/check_completion()
	if(SSticker && SSticker.mode && SSticker.mode.station_was_nuked)
		return TRUE
	return FALSE

GLOBAL_LIST_EMPTY(possible_items)
/datum/objective/steal
	name = "steal"
	var/datum/objective_item/targetinfo = null //Save the chosen item datum so we can access it later.
	var/obj/item/steal_target = null //Needed for custom objectives (they're just items, not datums).
	martyr_compatible = 0

/datum/objective/steal/get_target()
	return steal_target

/datum/objective/steal/New()
	..()
	if(!GLOB.possible_items.len)//Only need to fill the list when it's needed.
		for(var/I in subtypesof(/datum/objective_item/steal))
			new I

/datum/objective/steal/find_target()
	var/list/datum/mind/owners = get_owners()
	var/approved_targets = list()
	check_items:
		for(var/datum/objective_item/possible_item in GLOB.possible_items)
			if(!is_unique_objective(possible_item.targetitem))
				continue
			for(var/datum/mind/M in owners)
				if(M.current.mind.assigned_role in possible_item.excludefromjob)
					continue check_items
			approved_targets += possible_item
	return set_target(safepick(approved_targets))

/datum/objective/steal/proc/set_target(datum/objective_item/item)
	if(item)
		targetinfo = item
		steal_target = targetinfo.targetitem
		explanation_text = "Steal [targetinfo.name]"
		give_special_equipment(targetinfo.special_equipment)
		return steal_target
	else
		explanation_text = "Free objective"
		return

/datum/objective/steal/admin_edit(mob/admin)
	var/list/possible_items_all = GLOB.possible_items+"custom"
	var/new_target = input(admin,"Select target:", "Objective target", steal_target) as null|anything in possible_items_all
	if (!new_target)
		return

	if (new_target == "custom") //Can set custom items.
		var/custom_path = input(admin,"Search for target item type:","Type") as null|text
		if (!custom_path)
			return
		var/obj/item/custom_target = pick_closest_path(custom_path, make_types_fancy(subtypesof(/obj/item)))
		var/custom_name = initial(custom_target.name)
		custom_name = stripped_input(admin,"Enter target name:", "Objective target", custom_name)
		if (!custom_name)
			return
		steal_target = custom_target
		explanation_text = "Steal [custom_name]."

	else
		set_target(new_target)

/datum/objective/steal/check_completion()
	var/list/datum/mind/owners = get_owners()
	if(!steal_target)
		return TRUE
	for(var/datum/mind/M in owners)
		if(!isliving(M.current))
			continue

		var/list/all_items = M.current.GetAllContents()	//this should get things in cheesewheels, books, etc.

		for(var/obj/I in all_items) //Check for items
			if(istype(I, steal_target))
				if(!targetinfo) //If there's no targetinfo, then that means it was a custom objective. At this point, we know you have the item, so return 1.
					return TRUE
				else if(targetinfo.check_special_completion(I))//Returns 1 by default. Items with special checks will return 1 if the conditions are fulfilled.
					return TRUE

			if(targetinfo && (I.type in targetinfo.altitems)) //Ok, so you don't have the item. Do you have an alternative, at least?
				if(targetinfo.check_special_completion(I))//Yeah, we do! Don't return 0 if we don't though - then you could fail if you had 1 item that didn't pass and got checked first!
					return TRUE
	return FALSE


GLOBAL_LIST_EMPTY(possible_items_special)
/datum/objective/steal/special //ninjas are so special they get their own subtype good for them
	name = "steal special"

/datum/objective/steal/special/New()
	..()
	if(!GLOB.possible_items_special.len)
		for(var/I in subtypesof(/datum/objective_item/special) + subtypesof(/datum/objective_item/stack))
			new I

/datum/objective/steal/special/find_target()
	return set_target(pick(GLOB.possible_items_special))

/datum/objective/steal/exchange
	name = "exchange"
	martyr_compatible = 0

/datum/objective/steal/exchange/admin_edit(mob/admin)
	return

/datum/objective/steal/exchange/proc/set_faction(faction,otheragent)
	target = otheragent
	if(faction == "red")
		targetinfo = new/datum/objective_item/unique/docs_blue
	else if(faction == "blue")
		targetinfo = new/datum/objective_item/unique/docs_red
	explanation_text = "Acquire [targetinfo.name] held by [target.current.real_name], the [target.assigned_role] and syndicate agent"
	steal_target = targetinfo.targetitem


/datum/objective/steal/exchange/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Acquire [targetinfo.name] held by [target.name], the [target.assigned_role] and syndicate agent"
	else
		explanation_text = "Free Objective"


/datum/objective/steal/exchange/backstab
	name = "prevent exchange"

/datum/objective/steal/exchange/backstab/set_faction(faction)
	if(faction == "red")
		targetinfo = new/datum/objective_item/unique/docs_red
	else if(faction == "blue")
		targetinfo = new/datum/objective_item/unique/docs_blue
	explanation_text = "Do not give up or lose [targetinfo.name]."
	steal_target = targetinfo.targetitem

/datum/objective/download
	name = "download"

/datum/objective/download/proc/gen_amount_goal()
	target_amount = rand(20,40)
	update_explanation_text()
	return target_amount

/datum/objective/download/update_explanation_text()
	..()
	explanation_text = "Download [target_amount] research node\s."

/datum/objective/download/check_completion()
	var/datum/techweb/checking = new
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/owner in owners)
		if(ismob(owner.current))
			var/mob/M = owner.current			//Yeah if you get morphed and you eat a quantum tech disk with the RD's latest backup good on you soldier.
			if(ishuman(M))
				var/mob/living/carbon/human/H = M
				if(H && (H.stat != DEAD) && istype(H.wear_suit, /obj/item/clothing/suit/space/space_ninja))
					var/obj/item/clothing/suit/space/space_ninja/S = H.wear_suit
					S.stored_research.copy_research_to(checking)
			var/list/otherwise = M.GetAllContents()
			for(var/obj/item/disk/tech_disk/TD in otherwise)
				TD.stored_research.copy_research_to(checking)
	return checking.researched_nodes.len >= target_amount

/datum/objective/download/admin_edit(mob/admin)
	var/count = input(admin,"How many nodes ?","Nodes",target_amount) as num|null
	if(count)
		target_amount = count
	update_explanation_text()
/*
/datum/objective/capture
	name = "capture"
	var/captured_amount = 0

/datum/objective/capture/proc/gen_amount_goal()
	target_amount = rand(5,10)
	explanation_text = "Capture [target_amount] lifeform\s with an energy net. Live, rare specimens are worth more."
	return target_amount

/datum/objective/capture/update_explanation_text()
	. = ..()
	explanation_text = "Capture [target_amount] lifeform\s with an energy net. Live, rare specimens are worth more."

/datum/objective/capture/check_completion()//Basically runs through all the mobs in the area to determine how much they are worth.
	/*var/area/centcom/holding/A = GLOB.areas_by_type[/area/centcom/holding]
	for(var/mob/living/carbon/human/M in A)//Humans.
		if(M.stat == DEAD)//Dead folks are worth less.
			captured_amount+=0.5
			continue
		captured_amount+=1
	for(var/mob/living/carbon/monkey/M in A)//Monkeys are almost worthless, you failure.
		captured_amount+=0.1
	for(var/mob/living/carbon/alien/larva/M in A)//Larva are important for research.
		if(M.stat == DEAD)
			captured_amount+=0.5
			continue
		captured_amount+=1
	for(var/mob/living/carbon/alien/humanoid/M in A)//Aliens are worth twice as much as humans.
		if(istype(M, /mob/living/carbon/alien/humanoid/royal/queen))//Queens are worth three times as much as humans.
			if(M.stat == DEAD)
				captured_amount+=1.5
			else
				captured_amount+=3
			continue
		if(M.stat == DEAD)
			captured_amount+=1
			continue
		captured_amount+=2*/ //Removed in favour of adding points on capture, in energy_net_nets.dm
	return captured_amount >= target_amount

/datum/objective/capture/admin_edit(mob/admin)
	var/count = input(admin,"How many mobs to capture ?","capture",target_amount) as num|null
	if(count)
		target_amount = count
	update_explanation_text()
*/
//Changeling Objectives

/datum/objective/absorb
	name = "absorb"

/datum/objective/absorb/proc/gen_amount_goal(lowbound = 4, highbound = 6)
	target_amount = rand (lowbound,highbound)
	var/n_p = 1 //autowin
	var/list/datum/mind/owners = get_owners()
	if (SSticker.current_state == GAME_STATE_SETTING_UP)
		for(var/mob/dead/new_player/P in GLOB.player_list)
			if(P.client && P.ready == PLAYER_READY_TO_PLAY && !(P.mind in owners))
				n_p ++
	else if (SSticker.IsRoundInProgress())
		for(var/mob/living/carbon/human/P in GLOB.player_list)
			if(P.client && !(P.mind.has_antag_datum(/datum/antagonist/changeling)) && !(P.mind in owners))
				n_p ++
	target_amount = min(target_amount, n_p)

	update_explanation_text()
	return target_amount

/datum/objective/absorb/update_explanation_text()
	. = ..()
	explanation_text = "Extract [target_amount] compatible genome\s."

/datum/objective/absorb/admin_edit(mob/admin)
	var/count = input(admin,"How many people to absorb?","absorb",target_amount) as num|null
	if(count)
		target_amount = count
	update_explanation_text()

/datum/objective/absorb/check_completion()
	var/list/datum/mind/owners = get_owners()
	var/absorbedcount = 0
	for(var/datum/mind/M in owners)
		if(!M)
			continue
		var/datum/antagonist/changeling/changeling = M.has_antag_datum(/datum/antagonist/changeling)
		if(!changeling || !changeling.stored_profiles)
			continue
		absorbedcount += changeling.absorbedcount
	return absorbedcount >= target_amount

/datum/objective/absorb_most
	name = "absorb most"
	explanation_text = "Extract more compatible genomes than any other Changeling."

/datum/objective/absorb_most/check_completion()
	var/list/datum/mind/owners = get_owners()
	var/absorbedcount = 0
	for(var/datum/mind/M in owners)
		if(!M)
			continue
		var/datum/antagonist/changeling/changeling = M.has_antag_datum(/datum/antagonist/changeling)
		if(!changeling || !changeling.stored_profiles)
			continue
		absorbedcount += changeling.absorbedcount

	for(var/datum/antagonist/changeling/changeling2 in GLOB.antagonists)
		if(!changeling2.owner || changeling2.owner == owner || !changeling2.stored_profiles || changeling2.absorbedcount < absorbedcount)
			continue
		return FALSE
	return TRUE

/datum/objective/absorb_changeling
	name = "absorb changeling"
	explanation_text = "Absorb another Changeling."

/datum/objective/absorb_changeling/check_completion()
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!M)
			continue
		var/datum/antagonist/changeling/changeling = M.has_antag_datum(/datum/antagonist/changeling)
		if(!changeling)
			continue
		var/total_genetic_points = changeling.geneticpoints

		for(var/obj/effect/proc_holder/changeling/p in changeling.purchasedpowers)
			total_genetic_points += p.dna_cost

		if(total_genetic_points > initial(changeling.geneticpoints))
			return TRUE
	return FALSE

//End Changeling Objectives

/datum/objective/destroy
	name = "destroy AI"
	martyr_compatible = 1

/datum/objective/destroy/find_target()
	var/list/possible_targets = active_ais(1)
	var/mob/living/silicon/ai/target_ai = pick(possible_targets)
	target = target_ai.mind
	update_explanation_text()
	return target

/datum/objective/destroy/check_completion()
	if(target && target.current)
		return target.current.stat == DEAD || target.current.z > 6 || !target.current.ckey //Borgs/brains/AIs count as dead for traitor objectives.
	return TRUE

/datum/objective/destroy/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Destroy [target.name], the experimental AI."
	else
		explanation_text = "Free Objective"

/datum/objective/destroy/admin_edit(mob/admin)
	var/list/possible_targets = active_ais(1)
	if(possible_targets.len)
		var/mob/new_target = input(admin,"Select target:", "Objective target") as null|anything in possible_targets
		target = new_target.mind
	else
		to_chat(admin, "No active AIs with minds")
	update_explanation_text()

/datum/objective/destroy/internal
	var/stolen = FALSE 		//Have we already eliminated this target?

//Created by admin tools
/datum/objective/custom
	name = "custom"
	completable = FALSE

/datum/objective/custom/admin_edit(mob/admin)
	var/expl = stripped_input(admin, "Custom objective:", "Objective", explanation_text)
	if(expl)
		explanation_text = expl

////////////////////////////////
// Changeling team objectives //
////////////////////////////////

/datum/objective/changeling_team_objective //Abstract type
	martyr_compatible = 0	//Suicide is not teamwork!
	explanation_text = "Changeling Friendship!"
	var/min_lings = 3 //Minimum amount of lings for this team objective to be possible
	var/escape_objective_compatible = FALSE

/datum/objective/changeling_team_objective/proc/prepare()
	return FALSE

//Impersonate department
//Picks as many people as it can from a department (Security,Engineer,Medical,Science)
//and tasks the lings with killing and replacing them
/datum/objective/changeling_team_objective/impersonate_department
	explanation_text = "Ensure X department are killed, impersonated, and replaced by Changelings"
	var/command_staff_only = FALSE //if this is true, it picks command staff instead
	var/list/department_minds = list()
	var/list/department_real_names = list()
	var/department_string = ""


/datum/objective/changeling_team_objective/impersonate_department/prepare()
	var/result = FALSE
	if(command_staff_only)
		result = get_heads()
	else
		result = get_department_staff()
	if(result)
		update_explanation_text()
		return TRUE
	else
		return FALSE


/datum/objective/changeling_team_objective/impersonate_department/proc/get_department_staff()
	department_minds = list()
	department_real_names = list()

	var/list/departments = list("Head of Security","Research Director","Chief Engineer","Chief Medical Officer")
	var/department_head = pick(departments)
	switch(department_head)
		if("Head of Security")
			department_string = "security"
		if("Research Director")
			department_string = "science"
		if("Chief Engineer")
			department_string = "engineering"
		if("Chief Medical Officer")
			department_string = "medical"

	var/list/lings = get_antag_minds(/datum/antagonist/changeling,TRUE)
	var/ling_count = lings.len

	for(var/datum/mind/M in SSticker.minds)
		if(M in lings)
			continue
		if(department_head in get_department_heads(M.assigned_role))
			if(ling_count)
				ling_count--
				department_minds += M
				department_real_names += M.current.real_name
			else
				break

	if(!department_minds.len)
		log_game("[type] has failed to find department staff, and has removed itself. the round will continue normally")
		return FALSE
	return TRUE


/datum/objective/changeling_team_objective/impersonate_department/proc/get_heads()
	department_minds = list()
	department_real_names = list()

	//Needed heads is between min_lings and the maximum possible amount of command roles
	//So at the time of writing, rand(3,6), it's also capped by the amount of lings there are
	//Because you can't fill 6 head roles with 3 lings
	var/list/lings = get_antag_minds(/datum/antagonist/changeling,TRUE)
	var/needed_heads = rand(min_lings,GLOB.command_positions.len)
	needed_heads = min(lings.len,needed_heads)

	var/list/heads = SSjob.get_living_heads()
	for(var/datum/mind/head in heads)
		if(head in lings) //Looking at you HoP.
			continue
		if(needed_heads)
			department_minds += head
			department_real_names += head.current.real_name
			needed_heads--
		else
			break

	if(!department_minds.len)
		log_game("[type] has failed to find department heads, and has removed itself. the round will continue normally")
		return FALSE
	return TRUE


/datum/objective/changeling_team_objective/impersonate_department/update_explanation_text()
	..()
	if(!department_real_names.len || !department_minds.len)
		explanation_text = "Free Objective"
		return  //Something fucked up, give them a win

	if(command_staff_only)
		explanation_text = "Ensure changelings impersonate and escape as the following heads of staff: "
	else
		explanation_text = "Ensure changelings impersonate and escape as the following members of \the [department_string] department: "

	var/first = 1
	for(var/datum/mind/M in department_minds)
		var/string = "[M.name] the [M.assigned_role]"
		if(!first)
			string = ", [M.name] the [M.assigned_role]"
		else
			first--
		explanation_text += string

	if(command_staff_only)
		explanation_text += ", while the real heads are dead. This is a team objective."
	else
		explanation_text += ", while the real members are dead. This is a team objective."


/datum/objective/changeling_team_objective/impersonate_department/check_completion()
	if(!department_real_names.len || !department_minds.len)
		return TRUE //Something fucked up, give them a win

	var/list/check_names = department_real_names.Copy()

	//Check each department member's mind to see if any of them made it to centcom alive, if they did it's an automatic fail
	for(var/datum/mind/M in department_minds)
		if(M.has_antag_datum(/datum/antagonist/changeling)) //Lings aren't picked for this, but let's be safe
			continue

		if(M.current)
			var/turf/mloc = get_turf(M.current)
			if(mloc.onCentCom() && (M.current.stat != DEAD))
				return FALSE //A Non-ling living target got to centcom, fail

	//Check each staff member has been replaced, by cross referencing changeling minds, changeling current dna, the staff minds and their original DNA names
	var/success = 0
	changelings:
		for(var/datum/mind/changeling in get_antag_minds(/datum/antagonist/changeling,TRUE))
			if(success >= department_minds.len) //We did it, stop here!
				return TRUE
			if(ishuman(changeling.current))
				var/mob/living/carbon/human/H = changeling.current
				var/turf/cloc = get_turf(changeling.current)
				if(cloc && cloc.onCentCom() && (changeling.current.stat != DEAD)) //Living changeling on centcom....
					for(var/name in check_names) //Is he (disguised as) one of the staff?
						if(H.dna.real_name == name)
							check_names -= name //This staff member is accounted for, remove them, so the team don't succeed by escape as 7 of the same engineer
							success++ //A living changeling staff member made it to centcom
							continue changelings

	if(success >= department_minds.len)
		return TRUE
	return FALSE

//A subtype of impersonate_department
//This subtype always picks as many command staff as it can (HoS,HoP,Cap,CE,CMO,RD)
//and tasks the lings with killing and replacing them
/datum/objective/changeling_team_objective/impersonate_department/impersonate_heads
	explanation_text = "Have X or more heads of staff escape on the shuttle disguised as heads, while the real heads are dead"
	command_staff_only = TRUE


/datum/objective/hoard
	name = "hoard"
	var/obj/item/hoarded_item = null

/datum/objective/hoard/get_target()
	return hoarded_item

/datum/objective/hoard/proc/set_target(obj/item/I)
	if(I)
		hoarded_item = I
		explanation_text = "Keep [I] on your person at all times."
		return hoarded_item
	else
		explanation_text = "Free objective"
		return

/datum/objective/hoard/check_completion()
	var/list/datum/mind/owners = get_owners()
	if(!hoarded_item)
		return TRUE
	for(var/datum/mind/M in owners)
		if(!isliving(M.current))
			continue

		var/list/all_items = M.current.GetAllContents()	//this should get things in cheesewheels, books, etc.

		for(var/obj/I in all_items) //Check for items
			if(I == hoarded_item)
				return TRUE
	return FALSE

/datum/objective/hoard/heirloom
	name = "steal heirloom"

/datum/objective/hoard/heirloom/find_target()
	set_target(pick(GLOB.family_heirlooms))

GLOBAL_LIST_EMPTY(traitor_contraband)

GLOBAL_LIST_EMPTY(cult_contraband)

/datum/objective/hoard/collector
	name = "Hoard contraband"

/datum/objective/collector/New()
	..()
	if(!GLOB.traitor_contraband.len)//Only need to fill the list when it's needed.
		GLOB.traitor_contraband = list(/obj/item/card/emag/empty,/obj/item/clothing/glasses/phantomthief,/obj/item/clothing/gloves/chameleon/broken)
	if(!GLOB.cult_contraband.len)
		GLOB.cult_contraband = list(/obj/item/clockwork/slab,/obj/item/clockwork/component/belligerent_eye,/obj/item/clockwork/component/belligerent_eye/lens_gem,/obj/item/shuttle_curse,/obj/item/cult_shift)

/datum/objective/hoard/collector/find_target()
	var/obj/item/I
	var/I_type
	if(prob(50))
		I_type = pick_n_take(GLOB.traitor_contraband) // always unique unless it's run out, in which case we refill it anyway
	else
		I_type = pick_n_take(GLOB.cult_contraband)
	I = new I_type
	I.forceMove(get_turf(owner))
	if(ishuman(owner))
		var/mob/living/carbon/human/H = owner
		H.equip_in_one_of_slots(I, list("backpack" = SLOT_IN_BACKPACK))
		hoarded_item = I



GLOBAL_LIST_EMPTY(possible_sabotages)
// For saboteurs. Go in and cause some trouble somewhere. Not necessarily breaking things, just sufficiently troublemaking.
/datum/objective/sabotage
	name = "sabotage"
	var/datum/sabotage_objective/targetinfo = null //composition > inheritance.

/datum/objective/sabotage/get_target()
	return targetinfo.sabotage_type

/datum/objective/sabotage/New()
	..()
	if(!GLOB.possible_sabotages.len)//Only need to fill the list when it's needed.
		for(var/I in subtypesof(/datum/sabotage_objective))
			new I

/datum/objective/sabotage/find_target()
	var/list/datum/mind/owners = get_owners()
	var/approved_targets = list()
	check_sabotages:
		for(var/datum/sabotage_objective/possible_sabotage in GLOB.possible_sabotages)
			if(!is_unique_objective(possible_sabotage.sabotage_type) || possible_sabotage.check_conditions() || !possible_sabotage.can_run())
				continue
			for(var/datum/mind/M in owners)
				if(M.current.mind.assigned_role in possible_sabotage.excludefromjob)
					continue check_sabotages
			approved_targets += possible_sabotage
	return set_target(safepick(approved_targets))

/datum/objective/sabotage/proc/set_target(datum/sabotage_objective/sabo)
	if(sabo)
		targetinfo = sabo
		explanation_text = "[targetinfo.name]"
		give_special_equipment(targetinfo.special_equipment)
		return sabo
	else
		explanation_text = "Free objective"
		return

/datum/objective/sabotage/check_completion()
	return targetinfo.check_conditions()

/datum/objective/flavor
	name = "flavor"
	completable = FALSE
	var/flavor_file

/datum/objective/flavor/proc/get_flavor_list()
	return world.file2list(flavor_file)

/datum/objective/flavor/proc/forge_objective()
	var/flavor_list = get_flavor_list()
	explanation_text = pick(flavor_list)

/datum/objective/flavor/traitor
	name = "traitor flavor"
	flavor_file = "strings/flavor_objectives/traitor.txt"

/datum/objective/flavor/traitor/get_flavor_list()
	. = ..()
	switch(owner.assigned_role)
		if("Station Engineer", "Atmospheric Technician")
			. += world.file2list("strings/flavor_objectives/traitor/engineering.txt")
		if("Medical Doctor","Chemist","Virologist","Geneticist")
			. += world.file2list("strings/flavor_objectives/traitor/medical.txt")
		if("Scientist","Roboticist","Geneticist")
			. += world.file2list("strings/flavor_objectives/traitor/science.txt")
		if("Assistant")
			. += world.file2list("strings/flavor_objectives/traitor/assistant.txt")

/datum/objective/flavor/ninja_helping
	flavor_file = "strings/flavor_objectives/ninja_helping.txt"

/datum/objective/flavor/ninja_syndie
	flavor_file = "strings/flavor_objectives/ninja_syndie.txt"

/datum/objective/flavor/wizard
	flavor_file = "strings/flavor_objectives/wizard.txt"

/datum/objective/contract
	var/payout = 0
	var/payout_bonus = 0
	var/area/dropoff = null
	var/static/list/blacklisted_areas = typecacheof(list(/area/ai_monitored/turret_protected,
														/area/solar/,
														/area/ruin/,	//thank you station space ruins
														/area/science/test_area/,
														/area/shuttle/))

/datum/objective/contract/proc/generate_dropoff()	// Generate a random valid area on the station that the dropoff will happen.
	var/found = FALSE
	while(!found)
		var/area/dropoff_area = pick(GLOB.sortedAreas)
		if(dropoff_area && is_station_level(dropoff_area.z) && !dropoff_area.outdoors && !is_type_in_typecache(dropoff_area, blacklisted_areas))
			dropoff = dropoff_area
			found = TRUE

/datum/objective/contract/proc/dropoff_check(mob/user, mob/target)	// Check if both the contractor and contract target are at the dropoff point.
	var/area/user_area = get_area(user)
	var/area/target_area = get_area(target)
	return (istype(user_area, dropoff) && istype(target_area, dropoff))
