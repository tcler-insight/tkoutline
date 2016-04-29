# Tkoutline - an outline editor.
# Copyright (C) 2001-2003  Brian P. Theado
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
namespace eval tkoutline {
foreach {opt key} {
    *saveKey <Control-s>
    *saveAsKey <Meta-s>
    *closeKey <Meta-d>
    *newKey <Control-n>
    *openKey <Control-o>
    *exitKey <Alt-x>
    *helpKey F1
} {
option add $opt $key widget
}

outlinewidget::mapKeysToEvents {
    NextOutline
    PrevOutline
	Save
	SaveAs
	Open
    New
    Close
	Exit
    Help
    }
# Returns a shortened verions the physical event that corresponds
# to the given virtual event
proc describeEvent {event} {
    set info [lindex [event info $event] 0]
    regsub {Control-} $info {Ctrl-} info
    regsub {Key-} $info {} info
    set info [string map {< "" > ""} $info]
}

proc setMenuEntryStates {menu curWin} {
    set lastIdx [$menu index end]
    set bindings [bindtags $curWin]
    for {set idx 0} {$idx <= $lastIdx} {incr idx} {
        if {[$menu type $idx] == "command"} {
            # Get the event
            set cmd [$menu entryconfigure $idx -command]
            regexp {<<.*>>} $cmd event
            $menu entryconfigure $idx -state disabled
            #puts "$event inactive"
            foreach binding $bindings {
                #puts "binding $binding: [bind $binding $event]"
                if {[string length [bind $binding $event]] > 0} {
                    $menu entryconfigure $idx -state normal
                    #puts "$event activated due to binding $binding"
                    break
                }
            }
        }
    }
}
proc setupFileMenu {menu} {
    # The menu picks will generate events on the window that currently has focus
    set winCmd {[focus -lastfor .]}
    $menu configure -postcommand "::tkoutline::setMenuEntryStates $menu $winCmd; \
        $menu.subtree configure -postcommand \"::tkoutline::setMenuEntryStates $menu.subtree $winCmd\"; \
        $menu.import configure -postcommand \"::tkoutline::setMenuEntryStates $menu.import $winCmd\"; \
        $menu.export configure -postcommand \"::tkoutline::setMenuEntryStates $menu.export $winCmd\""
    $menu add command -label "Open..." -underline 0 -command "event generate $winCmd <<Open>>" -accelerator [describeEvent <<Open>>]
    $menu add command -label "New" -underline 0 -command "event generate $winCmd <<New>>"
    $menu add command -label "Save" -underline 0 -command "event generate $winCmd <<Save>>" -accelerator [describeEvent <<Save>>]
    $menu add command -label "Save As..." -underline 1 -command "event generate $winCmd <<SaveAs>>"
    menu $menu.subtree ;#-postcommand "::tkoutline::setMenuEntryStates $menu.subtree"
    $menu.subtree add command -label "Save" -underline 0 -command "event generate $winCmd <<SaveSubtree>>"
    $menu.subtree add command -label "Load" -underline 0 -command "event generate $winCmd <<LoadSubtree>>"
    $menu.subtree add command -label "Extract and Link" -underline 0 -command "event generate $winCmd <<ExtractSubtree>>"
    $menu add cascade -label "Subtree" -underline 2 -menu $menu.subtree
    menu $menu.import
    foreach format [treeconvert::getImportFormatsList] {
        $menu.import add command -label "$format" -underline 0 -command "event generate $winCmd <<ImportFrom$format>>"
    }
    $menu add cascade -label "Import from" -underline 0 -menu $menu.import
    menu $menu.export ;#-postcommand "::tkoutline::setMenuEntryStates $menu.export"
    foreach format [treeconvert::getExportFormatsList] {
        $menu.export add command -label "$format" -underline 0 -command "event generate $winCmd <<ExportTo$format>>"
    }
    $menu add cascade -label "Export to" -underline 0 -menu $menu.export
    $menu add separator
    $menu add command -label "Close" -underline 0 -command "event generate $winCmd <<Close>>"
    $menu add command -label "Exit" -underline 1 -command "event generate $winCmd <<Exit>>" -accelerator [describeEvent <<Exit>>]
}
proc setupHelpMenu {menu} {
    # The menu picks will generate events on the window that currently has focus
    set winCmd {[focus -lastfor .]}
    $menu add command -label "User Manual" -underline 0 -command "event generate $winCmd <<Help>>" -accelerator [describeEvent <<Help>>]
    $menu add command -label "About" -underline 0 -command "event generate $winCmd <<About>>"
}
proc setupEditMenu {menu} {
    set winCmd {[focus -lastfor .]}
    $menu configure -postcommand "::tkoutline::setMenuEntryStates $menu $winCmd"
    $menu add command -underline 2 -label "Cut" -command "event generate $winCmd <<Cut>>" -accelerator [describeEvent <<Cut>>]
    $menu add command -underline 0 -label "Copy" -command "event generate $winCmd <<Copy>>" -accelerator [describeEvent <<Copy>>]
    $menu add command -underline 0 -label "Paste" -command "event generate $winCmd <<Paste>>" -accelerator [describeEvent <<Paste>>]
    $menu add separator
    $menu add command -underline 6 -label "Edit Preferences" -command "event generate $winCmd <<Preferences>>" -accelerator [describeEvent <<Preferences>>]
    $menu add command -underline 5 -label "Edit Startup Script" -command "event generate $winCmd <<StartupScript>>" -accelerator [describeEvent <<StartupScript>>]

    
}
proc createMenuBar {win} {
    #frame $win -borderwidth 1 -relief raised
    menu $win -type menubar
    menu $win.file -tearoff 0
    setupFileMenu $win.file
    menu $win.edit -tearoff 0
    setupEditMenu $win.edit
    menu $win.outline -tearoff 0
    outlinewidget::setupOutlineMenu $win.outline
    menu $win.help -tearoff 0
    setupHelpMenu $win.help
    $win add cascade -label "File" -underline 0 -menu $win.file
    $win add cascade -label "Edit" -underline 0 -menu $win.edit
    $win add cascade -label "Outline" -underline 0 -menu $win.outline
    $win add cascade -label "Help" -underline 0 -menu $win.help
    return $win
}
}
