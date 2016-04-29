#==============================================================================
# Main Wcb package module.
#
# Copyright (c) 1999-2002  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

package require Tcl 8
package require Tk  8

namespace eval wcb {
    #
    # Public variables:
    #
    variable version	2.8
    variable library	[file dirname [info script]]

    #
    # Basic procedures:
    #
    namespace export	callback cbappend cbprepend cancel canceled \
			extend replace pathname

    #
    # Utility procedures for entry and spinbox widgets:
    #
    namespace export	changeEntryText postInsertEntryLen postInsertEntryText

    #
    # Simple before-insert callback routines for entry and spinbox widgets:
    #
    namespace export	checkStrForRegExp checkStrForAlpha checkStrForNum \
			checkStrForAlnum convStrToUpper convStrToLower

    #
    # Further before-insert callback routines for entry and spinbox widgets:
    #
    namespace export	checkEntryForInt  checkEntryForUInt \
			checkEntryForReal checkEntryForFixed \
			checkEntryLen

    #
    # Simple before-insert callback routines for text widgets:
    #
    namespace export	checkStrsForRegExp checkStrsForAlpha checkStrsForNum \
			checkStrsForAlnum convStrsToUpper convStrsToLower
}

package provide Wcb $wcb::version
package provide wcb $wcb::version

lappend auto_path [file join $wcb::library scripts]
