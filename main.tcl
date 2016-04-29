package require starkit
#source c:/apps/tcl/lib/tcllib1.3/profiler/profiler.tcl
#package require profiler 0.2.1
#profiler::init
if {[starkit::startup] == "sourced"} {return}
source [file join $starkit::topdir bin tkoutline.tcl]
