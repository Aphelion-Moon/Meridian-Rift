/// A bounded routing puzzle. Targets are drawn from a legal route, so every board is solvable.
/datum/cache_lock_puzzle
	/// Board width and height.
	var/grid_size = 6
	/// Pulses and recovery actions share this budget.
	var/buffer_limit = 8
	/// Trace begins with the first pulse, leaving the planning phase untimed.
	var/time_limit = 75 SECONDS
	/// Extra time bought by spending one buffer slot.
	var/recovery_time = 15 SECONDS
	/// Row-major symbol grid.
	var/list/cells = list()
	/// Two contiguous signatures, accepted in either order with overlap allowed.
	var/list/targets = list()
	/// Whether each signature has been uploaded.
	var/list/completed = list(FALSE, FALSE)
	/// Submitted symbols.
	var/list/buffer = list()
	/// Cell indices in pulse order; also determines the current position and next axis.
	var/list/used_cells = list()
	/// Absolute server deadline; zero until the first pulse.
	var/deadline = 0
	/// Whether the one-use recovery action has been consumed.
	var/recovery_used = FALSE
	/// All signatures have been uploaded.
	var/solved = FALSE
	/// Buffer exhaustion, a dead end, or the trace ended this attempt.
	var/failed = FALSE
	/// Reject duplicate/stale UI actions against a changed route.
	var/revision = 0

/datum/cache_lock_puzzle/New()
	. = ..()
	var/list/symbols = list("1C", "55", "7A", "BD", "E9", "FF")
	for(var/index in 1 to grid_size * grid_size)
		cells += pick(symbols)

	// Six steps cannot exhaust a six-cell row/column. Generate the route before
	// deriving targets, rather than hoping independently randomized targets fit.
	var/list/route = list()
	var/list/route_symbols = shuffle(symbols)
	var/previous = 0
	var/along_row = TRUE
	for(var/step in 1 to length(route_symbols))
		var/list/candidates = list()
		for(var/index in 1 to length(cells))
			if(!(index in route) && shares_line(index, previous, along_row))
				candidates += index
		previous = pick(candidates)
		route += previous
		cells[previous] = route_symbols[step]
		along_row = !along_row
	targets = list(route_symbols.Copy(1, 5), route_symbols.Copy(3, 7))

/// True when the cell is in the current legal row or column.
/datum/cache_lock_puzzle/proc/shares_line(index, previous, along_row)
	if(!previous)
		return index <= grid_size
	if(along_row)
		return round((index - 1) / grid_size) == round((previous - 1) / grid_size)
	return (index - 1) % grid_size == (previous - 1) % grid_size

/// Validates untrusted input as well as the server's current route and budget.
/datum/cache_lock_puzzle/proc/can_select(index)
	if(solved || failed || (deadline && world.time >= deadline) || length(buffer) >= buffer_limit)
		return FALSE
	if(!isnum(index) || index != round(index) || index < 1 || index > length(cells) || (index in used_cells))
		return FALSE
	var/pulses = length(used_cells)
	return shares_line(index, pulses ? used_cells[pulses] : 0, pulses % 2 == 0)

/// Accepts one legal pulse, then resolves signatures and terminal conditions.
/datum/cache_lock_puzzle/proc/select_cell(index)
	if(!can_select(index))
		return FALSE
	if(!deadline)
		deadline = world.time + time_limit
	used_cells += index
	buffer += cells[index]
	revision++
	resolve_buffer()
	return TRUE

/// Shared by the action and UI so recovery availability cannot drift from its rules.
/datum/cache_lock_puzzle/proc/can_stabilize()
	return deadline && world.time < deadline && !solved && !failed && !recovery_used && length(buffer) < buffer_limit - 1

/// Trades one unused buffer slot for additional trace time, preserving signature progress.
/datum/cache_lock_puzzle/proc/stabilize()
	if(!can_stabilize())
		return FALSE
	recovery_used = TRUE
	buffer_limit--
	deadline += recovery_time
	revision++
	resolve_buffer()
	return TRUE

/// Only complete contiguous signatures count; earlier completed signatures remain uploaded.
/datum/cache_lock_puzzle/proc/resolve_buffer()
	for(var/target_index in 1 to length(targets))
		var/list/target = targets[target_index]
		if(completed[target_index] || length(buffer) < length(target))
			continue
		var/matches = TRUE
		for(var/offset in 1 to length(target))
			if(buffer[length(buffer) - length(target) + offset] != target[offset])
				matches = FALSE
				break
		if(matches)
			completed[target_index] = TRUE
	solved = !(FALSE in completed)
	if(solved)
		return
	if(length(buffer) >= buffer_limit)
		failed = TRUE
		return
	for(var/index in 1 to length(cells))
		if(can_select(index))
			return
	failed = TRUE
