# TclDOM package index - hand crafted
#
# $Id: pkgIndex.tcl.in,v 1.15 2002/12/10 05:17:41 balls Exp $

package ifneeded dom::generic    2.6 [list load   [file join $dir @Tcldom_LIB_FILE@]]
package ifneeded dom::c          2.6 [list load   [file join $dir @Tcldom_LIB_FILE@]]
package ifneeded dom::tclgeneric 2.6 [list source [file join $dir dom.tcl]]
package ifneeded dom::tcl        2.6 [list source [file join $dir domimpl.tcl]]
package ifneeded dommap          1.0       [list source [file join $dir dommap.tcl]]
package ifneeded xmlswitch       1.0       [list source [file join $dir xmlswitch.tcl]]

# Examples - will not necessarily be installed
#package ifneeded cgi2dom         1.1       [list source [file join $dir cgi2dom.tcl]]
#package ifneeded domtree         2.6 [list source [file join $dir domtree.tcl]]

## Provided by separate package.
##package ifneeded dom::libxml2    2.6 [list load [file join $dir @RELPATH@ @TCLDOM_XML2_LIB_FILE@] Tcldomxml]

namespace eval ::dom {}

# Requesting the generic dom package loads the C package 
# if available, otherwise falls back to the generic Tcl package.
# The application can tell which it got by examining the
# list of packages loaded (and looking for dom::c or dom::tclgeneric).

package ifneeded dom 2.6 {
    if {[catch {package require dom::generic 2.6}]} {
	package require dom::tclgeneric
    } else {
	catch {package require dom::c}
	catch {package require dom::libxml2 2.6}
    }
    package provide dom 2.6

    # Both the C and pure Tcl versions of the generic layer
    # make use of the Tcl implementation.

    package require dom::tcl
}
