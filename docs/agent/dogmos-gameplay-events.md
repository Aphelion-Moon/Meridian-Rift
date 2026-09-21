# Dogmos gameplay callbacks

Native workers enqueue main-thread callbacks for reaction completion, pressure difference, decompression floor rip, firelock handling and settlement. DM resolves live targets and owns movement, visuals, reaction signals and turf replacement. Preserve order and validate deleted targets before applying effects.

Do not call DM from a numerical worker or while holding a lock required by the callback. Callback enqueue failure is an error, not permission to drop effects. Verify native numerical tests and real DreamDaemon gameplay fixtures separately.
