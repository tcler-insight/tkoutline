# Tkoutline - an outline editor.
# Copyright (C) 2001-2002  Brian P. Theado
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
package require Tk
package require struct
package require wcb
package require treeconvert

namespace eval tkoutline {
proc editTextFileAsOutline {fileName} {
    set od [::tkoutline::browser Open $fileName [::treeconvert::import $fileName IndentedAscii]]
    # Override the outline document's save function to export to text instead of saving in tkoutline's format
    $od proc Save {} {
        set ascii [treeconvert::treeToAscii [my outline treecmd] "" "    "]
        set fd [open [my set fileName] w]
        puts $fd $ascii
        close $fd
        my set modified 0
        }
    }
proc editPreferences {} {
    if {![file exists [file join ~ .tkoutline.def]]} {
        file copy [file join $::starkit::topdir .tkoutline.def] [file join ~ .tkoutline.def]
    }
    editTextFileAsOutline [file join ~ .tkoutline.def]
}
proc editUserStartupScript {} {
    set rcFile [file join ~ .tkoutlinerc]
    if {![file exists $rcFile]} {
        # create empty file with just one empty line
        set fd [open $rcFile w]
        puts $fd "# Tcl code added here will be executed when tkoutline starts"
        close $fd
    }
    editTextFileAsOutline $rcFile
}

proc importOutline {format} {
    set fileName [tk_getOpenFile -title "Import from $format" -filetypes [treeconvert::getFiletypesList $format]]
    if {[string length $fileName] == 0} {return}
    set tree [treeconvert::import $fileName $format]
}
proc createSafeInterp {interpName} {
    ::safe::interpCreate $interpName
    $interpName eval package require struct
    return 1
}

# Older versions of tkoutline store outline files as scripts that
# would contain struct::tree tcl commands to build the tree.  Here is a safe
# interpreter that can be used to safely source these files in.
# These old outline files were generated before the 2.0 API of struct::tree
# (which the new tkoutline uses), so redo some of the tree API so it works
# with the old pre 2.0 API
proc install-struct-1.x-compat {interpName} {
    $interpName eval namespace eval ::struct::tree {
        rename _set set.bak
        proc ::struct::tree::_set {name node args} {
            # $t set $n -key key ?value?
            if {[lindex $args 0] == "-key"} {
                return [eval set.bak $name $node [lrange $args 1 end]]
            }
            # $t set $n
            if {[llength $args] == 1} {
                return [set.bak $name $node title [lindex $args 0]]
            }
            # $t set $n title
            if {[llength $args] == 0} {
                return [set.bak $name $node title]
            }
        }
    }
}
proc remove-struct-1.x-compat {interpName} {
    $interpName eval {
        rename ::struct::tree::_set ""
        rename ::struct::tree::set.bak ::struct::tree::_set
    }
}
proc getTreeFromTclFile {{fileName ""}} {
    # Prompt for file if none given
    if {[string length $fileName] == 0} {
        set fileName [tk_getOpenFile]
        if {[string length $fileName] == 0} {return}
    }
    #cd [file dirname $fileName]
    #set fileName [file tail $fileName]

    # Load the tree using the safe interpreter
    if {[string length [info commands safeInterp]] == 0} {
        if {![createSafeInterp safeInterp]} {return [outlinewidget::getNewTree]}
    }
    install-struct-1.x-compat safeInterp
    set safetree [namespace tail [safeInterp invokehidden source $fileName]]
    interp alias {} safe-$safetree safeInterp $safetree

    # Now copy the tree into the main interpreter
    if {[safe-$safetree keyexists [safe-$safetree rootname] xpathEnabled]} {
        if {[safe-$safetree set [safe-$safetree rootname] xpathEnabled]} {
            package require tdomtree
            set tree [Tree new]
        } else {
            set tree [struct::tree]
        }
    } else {
        set tree [struct::tree]
    }
    remove-struct-1.x-compat safeInterp
    $tree = safe-$safetree

    # Cleanup
    safe-$safetree destroy
    interp alias {} safe-$safetree {}
    return $tree
}
proc getTreeFromList {list} {
    set tree [treeconvert::listToTree $list] 

    # This is experimental stuff which there really isn't end-user support
    # for.  Turns out this doesn't work anyways because I haven't implemented
    # the tree walk subcommand in tdomtree (which is used by treeToList when
    # saving the file.  Therefore, I comment this out until I fix tdomtree.
    if 0 {
    if {[$tree keyexists [$tree rootname] xpathEnabled]} {
        if {[$tree set [$tree rootname] xpathEnabled]} {
            $tree destroy
            package require tdomtree
            set tree [Tree new]
            treeconvert::listToTree $list $tree
        }
    }
    }
    return $tree
}
proc createTreeFromFileSpec {fileSpec} {
    set t [::struct::tree]
    $t set [$t rootname] expand 1
    foreach file [lsort -decreasing [glob -nocomplain $fileSpec]] {
        set n [$t insert [$t rootname] 0]
        $t set $n title "\[[file tail $file]]"
        $t set $n expand 0
    }
    if {[$t numchildren [$t rootname]] == 0} {
        set n [$t insert [$t rootname] 0]
        $t set $n expand 0
    }
    return $t
}
proc getTreeFromFile {{fileName ""}} {
    # Prompt for file if none given
    if {[string length $fileName] == 0} {
        set fileName [tk_getOpenFile]
        if {[string length $fileName] == 0} {return}
    }
    if {[file isdir $fileName]} {
        cd $fileName
        return [createTreeFromFileSpec [file join $fileName *]]
    } elseif {[llength [glob -nocomplain $fileName]] > 1} {
        return [createTreeFromFileSpec $fileName]
    }
    set fileName [lindex [glob $fileName] 0]
    set fd [open $fileName]
    set firstLine [gets $fd]
    if {[string match *struct::tree* $firstLine]} {
        # Old versions of tkoutline stored outlines as a script
        # Take care of backward compatibility here
        close $fd
        return [getTreeFromTclFile $fileName]
    } else {
        set list "$firstLine\n[read $fd]"
        close $fd
        return [getTreeFromList $list]
    }
}
proc saveTreeToFile {tree fileName} {
    if {[file exist $fileName]} {
        file delete $fileName~
        file copy $fileName $fileName~
        }
    set nestedList [treeconvert::treeToListMultiLine $tree]
    set f [open $fileName w]
    puts $f $nestedList
    close $f
}

proc saveSubtreeToFile {win tree node {fileName ""}} {
    outlinewidget::saveChangedTextToTree $win $tree
    if {[string length $fileName] == 0} {set fileName [tk_getSaveFile]}
    if {[string length $fileName] == 0} {return 0}
    
    # Convert node and descendents to a tree of its own and save to the file
    set subtree [::struct::tree]
    outlinewidget::copySubtree $tree $node $subtree [$tree rootname]
    #$subtree set root -key bulletType [$tree set root -key bulletType]
    saveTreeToFile $subtree $fileName
    $subtree destroy
    return 1
}
proc extractAndLinkSubtree {win tree node} {
    set fileName [string map {\[ "" \] ""} [$tree set $node title]]
    if {[file exists $fileName]} {
        set answer [tk_messageBox -message "$fileName already exists.  Do you want to replace it?" -type yesno]
        if {$answer == "no"} {return}
    }
    saveSubtreeToFile $win $tree $node $fileName
    $tree set $node title "\[$fileName\]"
    foreach child [$tree children $node] {
        $tree delete $child
    }
}
proc saveOutlineToFile {win tree {fileName ""}} {
    # Contents of the text widget can be different from the data in the actual
    # tree structure (stuff only gets saved to the tree when a node gets hidden)
    # so sync the tree structure from the text widget
    outlinewidget::saveChangedTextToTree $win $tree
    if {[string length $fileName] == 0} {
        set fileName [tk_getSaveFile]
        if {[string length $fileName] == 0} {return 0}
        setFileName $win $tree $fileName
    }
    markFileAsSaved $tree
    saveTreeToFile $tree $fileName
    return 1
}
proc loadFileAsSubtree {outline node {fileName ""}} {
    set subtree [getTreeFromFile $fileName]
    set savedHeadline [$outline tree set $node title]
    outlinewidget::copySubtree $subtree [$outline tree rootname] [$outline treecmd] $node
    $outline tree set $node title $savedHeadline
    $subtree destroy
    return
}
# From http://www.equi4.com/265
proc traverse {args} {
    set sig 0
    set mod 0
    while {[llength $args] > 0} {
      set d [lindex $args 0]
      set args [lrange $args 1 end]
      foreach path [lsort [glob -nocomplain [file join $d *]]] {
        set t [file tail $path]
        switch -- $t CVS - RCS - core - a.out continue
        lappend sig $t
        if {[file isdir $path]} {
          lappend args $path
        } else {
          set m [file mtime $path]
          if {$m > $mod} { set mod $m }
          lappend sig $m [file size $path]
        }
      }
    }
    package require crc32
    list [crc::crc32 [join $sig " "]] $mod
  }
proc version_id {dir {name ""}} {
    set versInfo [traverse $dir]
    set sig [lindex $versInfo 0]
    set mod [lindex $versInfo 1]
    set time [clock format $mod -format {%Y/%m/%d %H:%M:%S} -gmt 1]
    return [format {%s  %d-%d  %s} $time [expr {(($sig>>16) & 0xFFFF) + 10000}] \
                                        [expr {($sig & 0xFFFF) + 10000}] $name]
}
}
