# Tkoutline - an outline editor.
# Copyright (C) 2001  Brian P. Theado
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
namespace eval tkoutline {}

# Abstraction so things work with or without starkit packages
proc tkoutline::setupStarkit {} {
    variable topdir
    variable mode
    if {[info exists ::starkit::topdir]} {
        set topdir $::starkit::topdir
        if {[info exists ::starkit::mode]} {
            set mode $::starkit::mode
        } else {
            if {$topdir == [info nameofexe]} {
                set mode starpack
            } elseif {$::argv0 == [file join $topdir main.tcl]} {
                set mode starkit
            } else {
                set mode unwrapped
            }
        }
    } else {
        set topdir [file dirname [file dirname [file join [pwd] [info script]]]]
        set mode unwrapped
        set ::auto_path [concat [file join $topdir lib] $::auto_path]
    }
}
tkoutline::setupStarkit

# Allow files internal to a starkit to be sourced (i.e. for executing
# unittests)
if {([lindex $argv 0] == "-source") && ($argc == 2)} {
    # For some reason when running via wish, installed packages are being
    # used instead of ones in tkoutline lib dirs.  This is a hack to work
    # around this
    package forget struct wcb
    set fileName [lindex $argv 1]
    cd [file dirname $fileName]
    source $fileName
} else {
    # Normal operation
    proc tkoutline::createGui {} {
        variable scriptdir
        variable Buttons
        ::tkoutline::createMenuBar .mbar
        . configure -menu .mbar
        wm title . "Tkoutline"

        # Button bar functionality from Scott Gamon
        frame .buttonbar
        CreateButtonBar .buttonbar $Buttons
        pack .buttonbar \
            -side top \
            -fill x

        OutlineBrowser create browser ""
        set helpFile [file join [pwd] $scriptdir doc "User Manual"]
        set aboutFile [file join [pwd] $scriptdir doc "About Tkoutline"]
        bind . <<Preferences>> ::tkoutline::editPreferences
        bind . <<StartupScript>> ::tkoutline::editUserStartupScript
        bind . <<Help>> [list ::tkoutline::browser Open $helpFile]
        bind . <<About>> [list ::tkoutline::browser Open $aboutFile]
    }
    proc tkoutline::openInitialOutline {fileName} {
        if {[string length $fileName] == 0} {
            browser New
        } else {
            browser Open $fileName
        }
    }
    
    # Null function that can be overridden by the user.  Gets executed after
    # tkoutline is done initializing
    proc tkoutline::afterInit {} {}
    proc tkoutline::init {argv} {
        if {$::tcl_platform(platform) == "windows"} {
            # Italic and bold don't display properly in the default font for
            # windows (MS Sans Serif).  See Tk bug 478568.  Prevent the user
            # from seeing this bug by setting a different font as default
            option add *Text.font [list "Times New Roman" 11] startup
        }

        if {[llength $argv] == 1} {
            set fileName [file join [pwd] [string map {\\ /} [lindex $argv 0]]]
            if {![file isdir [file dirname $fileName]]} {
                tk_messageBox -icon error -message "Invalid path: [file dirname $fileName]"
                exit
            }
        } else {
            set fileName ""
        }
        createGui
        openInitialOutline $fileName
        afterInit
    }
    # Converts the given outline file to text and executes the resulting Tcl script
    proc tkoutline::sourceOutline fileName {
        package require treeconvert
        set fd [open $fileName]
        set list [read $fd]
        close $fd
        set tree [::treeconvert::listToTree $list]
        set script [::treeconvert::treeToAscii $tree "" "    "]
        uplevel $script
        }
    
    proc tkoutline::callBeforeHook {userCallback hookAndArgs op} {
        set hookArgs [lrange $hookAndArgs 1 end]
        uplevel $userCallback $hookArgs
    }
    proc tkoutline::callAfterHook {userCallback hookAndArgs args} {
        set hookArgs [lrange $hookAndArgs 1 end]
        uplevel $userCallback $hookArgs
    }
    proc tkoutline::registerHook {when function cmd} {
        switch -- $when {
            after {
                trace add execution $function leave [list ::tkoutline::callAfterHook $cmd]
            }
            before {
                trace add execution $function enter [list ::tkoutline::callBeforeHook $cmd]
            }
        }
    }
    proc tkoutline::execSelf args {
        variable mode
        variable topdir
        switch $mode {
            starkit -
            unwrapped {
                set cmd [list [info nameofexecutable] [file join $topdir $::argv0]]
            }
            starpack {
                set cmd [info nameofexecutable]
            }
        }
        return [eval exec [concat $cmd $args]]
    }
    proc tkoutline::loadPlugin {fileName script} {
        set plugin [file join [file dirname $::tkoutline::topdir] $fileName]
        if {![catch {uplevel source $plugin} msg]} {
            if {![catch {uplevel $script} msg]} {
                return $msg
            } else {
                console show
                puts "Error executing plugin script for $fileName: $msg"
            }
        } else {
            console show
            puts "Error loading plugin $fileName: $msg"
        }
    }

    proc tkoutline::sourceUserStartupScript {} {
        set startupScript [file join ~ .tkoutlinerc]
        if {[file exists $startupScript]} {
            uplevel #0 source $startupScript
        }
    }

    # Main code
    package require struct 2.0
    package require Tk
    set tkoutline::scriptdir [file dirname [file dirname [info script]]]
    option readfile [file join $tkoutline::scriptdir .tkoutline.def] startup
    catch {option readfile [file join ~ .tkoutline.def] user}
    package require outlinewidget
    source [file join $tkoutline::scriptdir lib tkoutline outlinefile.tcl]
    source [file join $tkoutline::scriptdir lib tkoutline outlinedocument.tcl]
    source [file join $tkoutline::scriptdir lib tkoutline outlinebrowser.tcl]
    source [file join $tkoutline::scriptdir lib tkoutline menubar.tcl]
    source [file join $tkoutline::scriptdir lib tkoutline ButtonBar.tcl]
    source [file join $tkoutline::scriptdir lib tkoutline tclcode2outline.tcl]
    tkoutline::sourceUserStartupScript
    tkoutline::init $argv
}
