/**
 * A stream of random draws seeded by text, the same on every server and in the reference generator, so a mask drawn
 * here matches the reference's pixel for pixel. The nth draw, counting from 0, is md5("[seed]:[n]") cut to its first
 * six hex digits: a 24-bit integer, which a DM number holds exactly.
 *
 * Everything built on draws spends them in the reference's order. Never take a draw with rand() or prob(), and never
 * take a modulo with % or %% on something that may come out negative: use DIRT_MODULO.
 */
/datum/dirt_random
	/// The text every draw hashes.
	var/seed
	/// How many draws the stream has made, which is the next draw's number.
	var/draw_count = 0

/**
 * Starts a stream at its first draw.
 *
 * Arguments:
 * - seed: The stream's text, spelled as the reference spells it ("aimed_chest:0"). Seeds are text: a number is written
 *   out in full, which matches the reference for whole numbers only.
 */
/datum/dirt_random/New(seed)
	. = ..()
	src.seed = istext(seed) ? seed : num2text(seed, 12)

/**
 * Returns the next draw, a whole number from 0 to 16777215.
 *
 * The draw's number goes into the hash in full, as the reference writes it, never in scientific notation.
 */
/datum/dirt_random/proc/draw()
	var/digest = md5("[seed]:[num2text(draw_count, 12)]")
	draw_count++
	return hex2num(copytext(digest, 1, 7))

/**
 * Returns the next draw as a fraction from 0 up to 1, never 1.
 */
/datum/dirt_random/proc/random()
	return draw() / 16777216

/**
 * Returns a number from `low` up to `high`, from one draw.
 *
 * Arguments:
 * - low: The smallest result.
 * - high: The bound the result stays under.
 */
/datum/dirt_random/proc/uniform(low, high)
	return low + (high - low) * random()

/**
 * Returns a whole number from 0 up to `count`, never `count`, from one draw.
 *
 * Arguments:
 * - count: How many results there are, a positive whole number.
 *
 * Crashes:
 * - Divides by zero when `count` is 0.
 */
/datum/dirt_random/proc/randrange(count)
	return draw() % count

/**
 * Returns a whole number from `low` to `high`, both included, from one draw.
 *
 * Arguments:
 * - low: The smallest result.
 * - high: The largest result, no less than `low`.
 */
/datum/dirt_random/proc/randint(low, high)
	return low + randrange(high - low + 1)

/**
 * Returns one of `options`, from one draw.
 *
 * Arguments:
 * - options: The list to pick from.
 *
 * Crashes:
 * - Divides by zero when `options` is empty.
 */
/datum/dirt_random/proc/choose(list/options)
	return options[randrange(length(options)) + 1]

/**
 * Returns a normally distributed number, from two draws (Box-Muller).
 *
 * The first draw is turned round to 1 - random(), so the log never sees 0. DM's trigonometry takes degrees.
 *
 * Arguments:
 * - mean: The centre of the distribution.
 * - deviation: Its standard deviation.
 */
/datum/dirt_random/proc/gauss(mean, deviation)
	var/radius_draw = 1 - random()
	var/angle_draw = random()
	return mean + deviation * sqrt(-2 * log(radius_draw)) * cos(360 * angle_draw)

/**
 * Shuffles `items` in place, from the last position down (Fisher-Yates), with one draw for each position but the first.
 *
 * Arguments:
 * - items: The list to shuffle.
 *
 * Returns:
 * - `items` itself, shuffled.
 */
/datum/dirt_random/proc/shuffle(list/items)
	for(var/position = length(items) - 1, position > 0, position--)
		var/swap = randrange(position + 1)
		items.Swap(position + 1, swap + 1)
	return items

/**
 * Returns `count` of `items` without repeats, as a new list: a Fisher-Yates from the front, stopped after `count`
 * draws. `items` is left as it was.
 *
 * Arguments:
 * - items: The list to pick from.
 * - count: How many to pick, no more than `items` holds.
 *
 * Crashes:
 * - Divides by zero when `count` is more than `items` holds.
 */
/datum/dirt_random/proc/sample(list/items, count)
	var/list/pool = items.Copy()
	for(var/position = 0, position < count, position++)
		var/swap = position + randrange(length(pool) - position)
		pool.Swap(position + 1, swap + 1)
	return pool.Copy(1, count + 1)

/**
 * Returns the table the noise hashes lattice points through: 0 to 255, shuffled by the "dirt:perm" stream.
 *
 * The table is built on the first call and shared after that. You should NEVER modify it.
 */
/proc/dirt_perm_table()
	RETURN_TYPE(/list)
	var/static/list/table
	if(!table)
		var/list/values = list()
		for(var/value in 0 to 255)
			values += value
		var/datum/dirt_random/stream = new("dirt:perm")
		table = stream.shuffle(values)
	return table

/**
 * Returns a lattice point's noise value, from 0 to 1 in steps of 1/255.
 *
 * The seed's low byte, its next byte and then the point's coordinates are chained through the permutation table.
 * DIRT_MODULO keeps every index in range when a coordinate is negative.
 *
 * Arguments:
 * - cell_x, cell_y: The lattice point, whole numbers of either sign.
 * - seed: The noise field's seed, a whole number.
 */
/proc/dirt_noise_hash(cell_x, cell_y, seed)
	var/static/list/table
	table ||= dirt_perm_table()
	var/seed_high = floor(seed / 256)
	var/chained = table[DIRT_MODULO(seed, 256) + 1] + DIRT_MODULO(seed_high, 256)
	chained = table[DIRT_MODULO(chained, 256) + 1] + cell_x
	chained = table[DIRT_MODULO(chained, 256) + 1] + cell_y
	return table[DIRT_MODULO(chained, 256) + 1] / 255

/**
 * Returns smooth value noise from 0 to 1: the four lattice points round a sample, blended with a smoothstep. Each point
 * is dirt_noise_hash()'s, its chain's seed steps taken once and each column's step once, for the four.
 *
 * Arguments:
 * - sample_x, sample_y: Where to sample, in pixels.
 * - seed: The noise field's seed, a whole number.
 * - scale: The lattice's spacing, in pixels.
 */
/proc/dirt_value_noise(sample_x, sample_y, seed, scale)
	var/static/list/table
	table ||= dirt_perm_table()
	var/scaled_x = sample_x / scale
	var/scaled_y = sample_y / scale
	var/cell_x = floor(scaled_x)
	var/cell_y = floor(scaled_y)
	var/blend_x = scaled_x - cell_x
	var/blend_y = scaled_y - cell_y
	blend_x = blend_x * blend_x * (3 - 2 * blend_x)
	blend_y = blend_y * blend_y * (3 - 2 * blend_y)
	var/seed_high = floor(seed / 256)
	var/chained = table[DIRT_MODULO(seed, 256) + 1] + DIRT_MODULO(seed_high, 256)
	var/seeded = table[DIRT_MODULO(chained, 256) + 1]
	chained = seeded + cell_x
	var/left = table[DIRT_MODULO(chained, 256) + 1]
	chained = seeded + cell_x + 1
	var/right = table[DIRT_MODULO(chained, 256) + 1]
	chained = left + cell_y
	var/top_left = table[DIRT_MODULO(chained, 256) + 1] / 255
	chained = right + cell_y
	var/top_right = table[DIRT_MODULO(chained, 256) + 1] / 255
	chained = left + cell_y + 1
	var/bottom_left = table[DIRT_MODULO(chained, 256) + 1] / 255
	chained = right + cell_y + 1
	var/bottom_right = table[DIRT_MODULO(chained, 256) + 1] / 255
	return (top_left + (top_right - top_left) * blend_x) * (1 - blend_y) + (bottom_left + (bottom_right - bottom_left) * blend_x) * blend_y

/**
 * Returns two octaves of value noise, stretched back out to cover 0 to 1 (summed noise bunches round 0.5).
 *
 * The second octave is half the scale, on the seed plus 97.
 *
 * Arguments:
 * - sample_x, sample_y: Where to sample, in pixels.
 * - seed: The noise field's seed, a whole number.
 * - scale: The first octave's lattice spacing, in pixels.
 */
/proc/dirt_spread_noise(sample_x, sample_y, seed, scale)
	var/mixed = (dirt_value_noise(sample_x, sample_y, seed, scale) * 2 + dirt_value_noise(sample_x, sample_y, seed + 97, scale / 2)) / 3
	return clamp(0.5 + (mixed - 0.5) * 2.4, 0, 1)
