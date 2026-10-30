// BYOND 516 throws false unused_var warnings in procs nobody touched as the tree grows, and CI fails the build on any warning
#if !defined(SPACEMAN_DMM) && !defined(OPENDREAM)
#pragma ignore unused_var
#endif
