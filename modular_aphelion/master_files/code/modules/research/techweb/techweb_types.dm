// Admin Techweb, this surely isnt a mistake.
// Must stay under /autounlocking: the design_source unit test only counts a design as reachable if it turns up in a
// techweb node, a design disk, or an autounlocking techweb.
/datum/techweb/autounlocking/admin
	allowed_buildtypes = ADMIN_TECHWEB | COLONY_FABRICATOR
