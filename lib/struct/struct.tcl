package require Tcl 8.2
package provide struct 2.0

source [file join [file dirname [info script]] tree.tcl]
source [file join [file dirname [info script]] list.tcl]
source [file join [file dirname [info script]] prune.tcl]

namespace eval ::struct {
    namespace import -force tree::*
    namespace import -force list::*
    namespace export *
}
