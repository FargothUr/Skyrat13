SUBSYSTEM_DEF(language)
	name = "Language"
	init_order = INIT_ORDER_LANGUAGE
	flags = SS_NO_FIRE
	var/list/languages_by_name = list() //SKYRAT CHANGE - language bullshit

/datum/controller/subsystem/language/Initialize(timeofday)
	for(var/L in subtypesof(/datum/language))
		var/datum/language/language = L
		if(!initial(language.key))
			continue

		GLOB.all_languages += language

		var/datum/language/instance = new language

		GLOB.language_datum_instances[language] = instance
		//skyrat change
		languages_by_name[initial(language.name)] = new language
		//

	return ..()

//Skyrat change
/datum/controller/subsystem/language/proc/AssignLanguage(mob/living/user, client/cli)
	var/list/my_lang = cli.prefs.language
	if(isnull(my_lang))
		return
	for(var/I in GLOB.all_languages)
		var/datum/language/L = I
		var/datum/language/cool = new L
		if(my_lang == cool.name)
			if(!cool.restricted || (cool.name in cli.prefs.pref_species.languagewhitelist))
				user.grant_language(cool.type, TRUE, TRUE, LANGUAGE_ADDITIONAL)
				to_chat(user, "<span class='notice'>You are able to speak in [my_lang]. If you're actually good at it or not, it's up to you.</span>")
			else
				for(var/datum/quirk/Q in cli.prefs.all_quirks)
					if(cool.name in Q.languagewhitelist)
						user.grant_language(cool, TRUE, TRUE, LANGUAGE_ADDITIONAL)
						to_chat(user, "<span class='notice'>You are able to speak in [my_lang]. If you're actually good at it or not, it's up to you.</span>")
						return
				to_chat(user, "<span class='warning'>Uh oh. [my_lang] is a restricted language, and couldn't be assigned!</span>")
				to_chat(user, "<span class='warning'>This probably shouldn't be happening. Scream at Bob on #main-dev.</span>")
		else
			continue
	var/mob/living/carbon/H = user
	if(istype(H))
		if(cli.prefs.say_verb)
			H.dna.species.say_mod = cli.prefs.say_verb
		if(cli.prefs.ask_verb)
			H.dna.species.ask_mod = cli.prefs.ask_verb
		if(cli.prefs.exclaim_verb)
			H.dna.species.exclaim_mod = cli.prefs.exclaim_verb
		if(cli.prefs.whisper_verb)
			H.dna.species.whisper_mod = cli.prefs.whisper_verb
		if(cli.prefs.yell_verb)
			H.dna.species.yell_mod = cli.prefs.yell_verb
	if(cli.prefs.speech_replacers.len || cli.prefs.speech_spans.len)
		var/datum/speech_mod/custom/C = new()
		if(cli.prefs.speech_soundtext)
			C.soundtext = cli.prefs.speech_soundtext
		if(cli.prefs.speech_spans.len)
			C.speech_spans = cli.prefs.speech_spans.Copy()
		if(cli.prefs.ignored_speech.len)
			C.ignored_languages = cli.prefs.ignored_speech.Copy()
		if(cli.prefs.exclusive_speech.len)
			C.exclusive_languages = cli.prefs.exclusive_speech.Copy()
		if(cli.prefs.speech_replacers.len)
			C.replacers = cli.prefs.speech_replacers.Copy()
		C.add_speech_mod(user)
//
