SUBSYSTEM_DEF(overlays)
	name = "Overlay"
	flags = SS_TICKER
	wait = 1
	priority = FIRE_PRIORITY_OVERLAYS
	init_order = INIT_ORDER_OVERLAY

	var/list/queue
	var/list/stats

/datum/controller/subsystem/overlays/PreInit()
	queue = list()
	stats = list()

/datum/controller/subsystem/overlays/Initialize()
	initialized = TRUE
	fire(mc_check = FALSE)
	return ..()


/datum/controller/subsystem/overlays/stat_entry()
	..("Ov:[length(queue)]")


/datum/controller/subsystem/overlays/Recover()
	queue = SSoverlays.queue


/datum/controller/subsystem/overlays/fire(resumed = FALSE, mc_check = TRUE)
	var/list/queue = src.queue
	var/static/count = 0
	if (count)
		var/c = count
		count = 0 //so if we runtime on the Cut, we don't try again.
		queue.Cut(1,c+1)

	for (var/thing in queue)
		count++
		if(thing)
			STAT_START_STOPWATCH
			var/atom/A = thing
			COMPILE_OVERLAYS(A)
			UNSETEMPTY(A.add_overlays)
			UNSETEMPTY(A.remove_overlays)
			STAT_STOP_STOPWATCH
			STAT_LOG_ENTRY(stats, A.type)
		if(mc_check)
			if(MC_TICK_CHECK)
				break
		else
			CHECK_TICK

	if (count)
		queue.Cut(1,count+1)
		count = 0

/proc/iconstate2appearance(icon, iconstate)
	var/static/image/stringbro = new()
	stringbro.icon = icon
	stringbro.icon_state = iconstate
	return stringbro.appearance

/proc/icon2appearance(icon)
	var/static/image/iconbro = new()
	iconbro.icon = icon
	return iconbro.appearance

/atom/proc/build_appearance_list(old_overlays)
	var/static/image/appearance_bro = new()
	var/list/new_overlays = list()
	if (!islist(old_overlays))
		old_overlays = list(old_overlays)
	for (var/overlay in old_overlays)
		if(!overlay)
			continue
		if (istext(overlay))
			new_overlays += iconstate2appearance(icon, overlay)
		else if(isicon(overlay))
			new_overlays += icon2appearance(overlay)
		else
			if(isloc(overlay))
				var/atom/A = overlay
				if (A.flags_atom & OVERLAY_QUEUED)
					COMPILE_OVERLAYS(A)
			appearance_bro.appearance = overlay //this works for images and atoms too!
			if(!ispath(overlay))
				var/image/I = overlay
				appearance_bro.dir = I.dir
			new_overlays += appearance_bro.appearance
	return new_overlays

#define NOT_QUEUED_ALREADY (!(flags_atom & OVERLAY_QUEUED))
#define QUEUE_FOR_COMPILE flags_atom |= OVERLAY_QUEUED; SSoverlays.queue += src;
/atom/proc/cut_overlays(priority = FALSE)
	LAZYINITLIST(priority_overlays)
	LAZYINITLIST(remove_overlays)
	remove_overlays = overlays.Copy()
	add_overlays = null

	if(priority)
		priority_overlays.Cut()

	//If not already queued for work and there are overlays to remove
	if(NOT_QUEUED_ALREADY && length(remove_overlays))
		QUEUE_FOR_COMPILE

/atom/proc/cut_overlay(list/overlays, priority)
	if(!overlays)
		return
	overlays = build_appearance_list(overlays)
	LAZYINITLIST(add_overlays)
	LAZYINITLIST(priority_overlays)
	LAZYINITLIST(remove_overlays)
	var/a_len = length(add_overlays)
	var/r_len = length(remove_overlays)
	var/p_len = length(priority_overlays)
	remove_overlays += overlays
	add_overlays -= overlays


	if(priority)
		var/list/cached_priority = priority_overlays
		LAZYREMOVE(cached_priority, overlays)

	var/fa_len = length(add_overlays)
	var/fr_len = length(remove_overlays)
	var/fp_len = length(priority_overlays)

	//If not already queued and there is work to be done
	if(NOT_QUEUED_ALREADY && (fa_len != a_len || fr_len != r_len || fp_len != p_len))
		QUEUE_FOR_COMPILE
	UNSETEMPTY(add_overlays)

/atom/proc/add_overlay(list/overlays, priority = FALSE)
	if(!overlays)
		return

	overlays = build_appearance_list(overlays)

	LAZYINITLIST(add_overlays) //always initialized after this point
	LAZYINITLIST(priority_overlays)
	var/a_len = length(add_overlays)
	var/p_len = length(priority_overlays)

	if(priority)
		priority_overlays += overlays  //or in the image. Can we use [image] = image?
		var/fp_len = length(priority_overlays)
		if(NOT_QUEUED_ALREADY && fp_len != p_len)
			QUEUE_FOR_COMPILE
	else
		add_overlays += overlays
		var/fa_len = length(add_overlays)
		if(NOT_QUEUED_ALREADY && fa_len != a_len)
			QUEUE_FOR_COMPILE

/atom/proc/copy_overlays(atom/other, cut_old)	//copys our_overlays from another atom
	if(!other)
		if(cut_old)
			cut_overlays()
		return

	var/list/cached_other = other.overlays.Copy()
	if(cached_other)
		if(cut_old || !LAZYLEN(overlays))
			remove_overlays = overlays
		add_overlays = cached_other
		if(NOT_QUEUED_ALREADY)
			QUEUE_FOR_COMPILE
	else if(cut_old)
		cut_overlays()

#undef NOT_QUEUED_ALREADY
#undef QUEUE_FOR_COMPILE

//TODO: Better solution for these?
/image/proc/add_overlay(x)
	overlays |= x

/image/proc/cut_overlay(x)
	overlays -= x

/image/proc/cut_overlays(x)
	overlays.Cut()

/image/proc/copy_overlays(atom/other, cut_old)
	if(!other)
		if(cut_old)
			cut_overlays()
		return

	var/list/cached_other = other.overlays.Copy()
	if(cached_other)
		if(cut_old || !length(overlays))
			overlays = cached_other
		else
			overlays |= cached_other
	else if(cut_old)
		cut_overlays()
