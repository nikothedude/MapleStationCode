//Extends /obj/machinery/hydroponics for modular access

/obj/machinery/hydroponics
	//Var that makes regular trays unable to handle xenobotany seeds
	var/accept_alien_seeds = FALSE

//Xenobotany tray
/obj/machinery/hydroponics/xeno_tray
	name = "xenobotany tray"
	icon_state = "hydrotray2"
	accept_alien_seeds = TRUE

//Alien seed check
/obj/machinery/hydroponics/alien_check
	if (myseed.is_alien_seed && accept_alien_seeds)
		to_chat(user, span_warning("This tray doesn't accept these seeds!"))
