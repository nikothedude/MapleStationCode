//Extends /obj/machinery/hydroponics for modular access

/obj/machinery/hydroponics
	//Var that makes regular trays unable to handle xenobotany seeds
	var/accept_alien_seeds = FALSE
	var/accept_produce_seeds = TRUE

//Xenobotany tray
/obj/machinery/hydroponics/xeno_tray
	name = "xenobotany tray"
	icon_state = "hydrotray2"
	accept_alien_seeds = TRUE
	accept_produce_seeds = FALSE

//We don't wanna grow weird stuff!
/obj/machinery/hydroponics/constructable
	accept_alien_seeds = FALSE

/obj/machinery/hydroponics/soil
	accept_alien_seeds = FALSE

//Alien seed check
/obj/machinery/hydroponics/proc/alien_check(mob/user, obj/item/seeds/seed)
	if(seed.is_alien_seed && !accept_alien_seeds)
		to_chat(user, span_warning("This tray does not accept [seed]!"))
		return FALSE
	return TRUE

//Produce seed check
/obj/machinery/hydroponics/proc/produce_check(mob/user, obj/item/seeds/seed)
	if(seed.is_produce_seed && !accept_produce_seeds)
		to_chat(user, span_warning("This tray does not accept [seed]!"))
		return FALSE
	return TRUE
