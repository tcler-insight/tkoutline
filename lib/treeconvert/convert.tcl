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
namespace eval treeconvert {
namespace export *
proc treeToAscii {tree {prefix "* "} {indentStr \t}} {
    set ascii {}

    # Visit each node and execute the given command 
    $tree walk [$tree rootname] n { 
        if {[$tree depth $n] != 0} {
            set indent "[string repeat $indentStr [expr [$tree depth $n] - 1]]$prefix" 
            append ascii "$indent[$tree set $n title]\n" 
        }
    } 
    return $ascii
}

# Ascii output with wrapped text
proc treeToEmail {tree} {
    package require textutil
    set text {}
    set indent "  "
    $tree walk [$tree rootname] node { 
        if {[$tree depth $node] != 0} {
            if {[$tree keyexists $node nobullet]} {
                set bullet ""
            } else {
                set bullet "- "
            }
            set curIndent [string repeat $indent [expr [$tree depth $node] - 1]]
            set length [expr 72 - [string length $curIndent$indent]]
            set headline [textutil::adjust [$tree set $node title] -length $length -strictlength 1]
            regsub -all \n $headline \n$curIndent$indent headline
            append text $curIndent$bullet$headline\n
        }
    } 
    return $text
}

proc treeToList {tree} {
    set list ""
    $tree walk [$tree rootname] -order both {a node} {
        switch $a {
            enter {
                lappend list [$tree getall $node] {}
            }
            leave {
                if {[llength $list] > 2} {
                    set curChildren [lindex $list end-2]
                    set newChildren [concat $curChildren [list [lrange $list end-1 end]]]

                    set list [lreplace $list end-2 end $newChildren]
                } else {
                    set list [list $list]
                }
            }
        }
    }
    return $list
}

# Same as treeToList, except each node is on a separate line so diff
# can be used meaningfully
proc treeToListMultiLine {tree} {
    return [string map {"title \{" "title \n\{"} [treeToList $tree]]
}
# sublist is a list of nodes
proc sublistToTree {tree node sublist} {
    set curNode $node
    set idx 0
    foreach nodeList $sublist {
        set curNode [$tree insert $node $idx]
        foreach {attr value} [lindex $nodeList 0] {
            if {$attr == "data"} {set attr title}
            $tree set $curNode $attr $value
        }
        if {[llength [lindex $nodeList 1]] > 0} {
            sublistToTree $tree $curNode [lindex $nodeList 1]
        }
        incr idx
    }
}
proc listToTree {list {tree ""}} {
    if {[string length $tree] == 0} {
        set tree [struct::tree]
        namespace export [namespace tail $tree]
        namespace eval :: "namespace import $tree"
    }
    set rootList [lindex $list 0]
    foreach {attr value} [lindex $rootList 0] {
        $tree set [$tree rootname] $attr $value
    }
    if {[llength [lindex $rootList 1]] > 0} {
        sublistToTree $tree [$tree rootname] [lindex $rootList 1]
    }
    return [namespace tail $tree]
}

# Returns a script that will regenerate the given node and its descendents
proc nodeToScript {tree node} {
    set script "\$t insert [$tree parent $node] [expr [$tree index $node] + 1] $node\n"
    foreach key [$tree keys $node] {
        append script "\$t set $node $key [list [$tree set $node $key]]\n"
    }
    foreach child [$tree children $node] {
        append script [nodeToScript $tree $child]
    }
    return $script
}

# Returns a script that will regenerate the given tree
proc treeToScript {tree} {
    set script "set t \[::struct::tree]\n"
    append script "\$t set root expand 1\n"
    append script "\$t set root bulletType [$tree set root bulletType]\n"
    if {[$tree keyexists root xpathEnabled]} {
        append script "\$t set root xpathEnabled [$tree set root xpathEnabled]\n"
    }
    foreach child [$tree children [$tree rootname]] {
        append script [nodeToScript $tree $child]
    }
    
    # Last line of the script returns the name of the tree
    append script "return \$t\n";
    return $script
}
proc nodeTextToHtml {text} {
    set styleRe {(^|[[:space:]])(%s)([^[:space:]].*?[^[:space:]])\2($|[[:space:]])} 
    
    # When a regexp contains a branch, it defaults to longest match.  The
    # following forces shortest match
    set styleRe "(?:$styleRe){1,1}?" 
    foreach {char tag} {{\*} b - s _ u / i} {
        set re [format $styleRe $char]
        regsub -all $re $text \\1<$tag>\\3</$tag>\\4 text
    }
    set urlRe {\m(https?|ftp|file|news|mailto):(\S+[^\]\)\s\.,!\?;:'>])}
    regsub -all $urlRe $text {<a href="\0">\0</a>} text
    return $text
}
proc treeToHtml {tree} {
    set html {}
    append html "<html><head></head><body>"
    set bulletType bullet
    if {[$tree keyexists [$tree rootname] bulletType]} {
        set bulletType [$tree set [$tree rootname] bulletType]
    }
    set maxHeader -1
    if {[$tree keyexists root maxHeader]} {
        set maxHeader [$tree set root maxHeader]
    }
    if {$bulletType == "bullet"} {
        set listTag "ul"
    } else {
        set listTag "ol"
    }
    $tree walk [$tree rootname] -order both {a n} {
        switch $a {
            enter {
                if {[$tree depth $n] != 0} {
                    if {[$tree depth $n] <= $maxHeader} {
                       append html "<h[$tree depth $n]>[htmlEncode [$tree set $n title]]</h[$tree depth $n]>"
                    } else {
                        if {[$tree keyexists $n nobullet]} {
                            set bulletTag p 
                        } else {
                            set bulletTag li
                        }
                            append html "<$bulletTag>[nodeTextToHtml [htmlEncode [$tree set $n title]]]\n"
                        if {![$tree isleaf $n]} {
                            append html "<$listTag>\n"
                        }
                    }
                }
            }
            leave {
                if {![$tree isleaf $n] && ([$tree depth $n] != 0)} {
                    append html "</$listTag>\n"
                }
            }
        }
    }
    append html "</body></html>"
    return $html
}
proc treeToXml {tree} {
    set xml {}
    $tree walk [$tree rootname] -order both {a n} {
        switch $a {
            enter {
                if {[$tree depth $n] == 0} {
                    append xml "<outline>\n"
                } else {
                    set indent [string repeat "    " [expr [$tree depth $n] - 1]] 
                    append xml "$indent<node title=\"[xmlEncode [nodeTextToHtml [$tree set $n title]]]\""
                    foreach key [$tree keys $n] {
                        if {$key != "title"} {
                            append xml " $key=\"[xmlEncode [$tree set $n $key]]\""
                        }
                    }
                    if {[$tree isleaf $n]} {
                        append xml "/"
                    }
                    append xml ">\n"
                }
            }
            leave {
                if {[$tree depth $n] == 0} {
                    append xml "</outline>\n"
                } elseif {![$tree isleaf $n]} {
                    append xml "</node>\n"
                }
            }
        }
    }
    return $xml
}
proc indent {String {NumChars 5}} {
	set String "[string repeat { } $NumChars]$String"

	return $String
}
proc treeToOpml {tree} {
	set opml {}
	set opmlHead {}
    set opmlBody {}
	
	set Modified [clock format [clock seconds] -format "%a, %d %b %Y %H:%M:%S GMT" -gmt 1]

	set opmlHead [subst {
     <head>
          <title/>
          <dateCreated>$Modified</dateCreated>
          <dateModified>$Modified</dateModified>
          <ownerName/>
          <ownerEmail/>
          <expansionState/>
          <vertScrollState/>
          <windowTop/>
          <windowLeft/>
          <windowBottom/>
          <windowRight/>
     </head>
}]

    if {![$tree keyexists [$tree rootname] title]} {$tree set [$tree rootname] title {}}
    $tree walk [$tree rootname] -order both {a node} {
        switch $a {
            enter {
				append opmlBody [opmlSerializeNodeOpen $tree $node]
            }
            leave {
				append opmlBody [opmlSerializeNodeClose $tree $node]
            }
        }
    }

	set opml [subst {<?xml version="1.0" encoding="ISO-8859-1"?>
<opml version="1.0">
$opmlHead
$opmlBody
</opml>
}]

    return $opml
}
proc htmlEncode {string} {
    return [string map {& &amp; < &lt; > &gt;} $string]
}

proc xmlEncode {string} {
    return [string map {\" &quot; & &amp; < &lt; > &gt; ' &apos;} $string]
}

proc opmlSerializeNodeOpen {tree node} {
	set Text [xmlEncode [nodeTextToHtml [$tree get $node title]]]
	set Tag [subst {<outline text="$Text">}]
	if {[$tree depth $node] == 0} {
		set Tag "<body>\n"
	}
	set NumChars [expr {([$tree depth $node] * 5) + 5}]
	set opml [indent $Tag $NumChars]
	if {[$tree children $node] != ""} {
		append opml "\n"
	}
	return $opml
}

proc opmlSerializeNodeClose {tree node} {
	set opml "</outline>\n"
	if {[$tree depth $node] == 0} {
		set opml "</body>\n"
	}
	if {[$tree children $node] != ""} {
		set NumChars [expr {([$tree depth $node] * 5) + 5}]
		set opml [indent $opml $NumChars]
	}
	return $opml
}

proc getImportFormatsList {args} {
	return [list IndentedAscii Opml]
}
# SG: this list is used in 2 places in outline.tcl, so I centralize it here
proc getExportFormatsList {args} {
	return [list Ascii Html Xml Email Opml]
}
# :SG

# SG: Returns a list of filetypes.  
#     Used by tk_getSaveFile, in [exportOutline], in outline.tcl
proc getFiletypesList {format} {
	set lstFiletypes [list {{All files} *}] 
	switch -- $format {
		Ascii - Email {}
		Html  {lappend lstFiletypes [list Html [list .html .htm]]}
		default {lappend lstFiletypes [list $format [string tolower ".$format"]]}
	}
	
	return $lstFiletypes
}
# :SG

proc export {tree fileName format} {
    set output [treeTo$format $tree]
    set f [open $fileName w]
    puts $f $output
    close $f
}
proc import {fileName format} {
    set fd [open $fileName]
    set contents [read $fd]
    close $fd
    set tree [[string tolower $format]ToTree $contents]
    $tree walk [$tree rootname] n {$tree set $n expand [expr ![$tree isleaf $n]]}
    return $tree
}

# Creates a tree from the given text.  If a tree, node, and index are
# provided, then the nodes are inserted into that tree as children of
# the given node at the given index.
# Each line of text is inserted into the tree as a different node.
# Differences in the amount of whitespace at the beginning of each
# line determines the level at which each node is created.
proc textToTree {string {tree ""} {node root} {startIdx 0}} {
    set string [string trimright $string \n]

    # Scan each line for how many indent characters it has
    set numIndentChars {}
    foreach line [split $string \n] {
       if {[regexp {^[ \t]+} $line indent]} {
          lappend numIndentChars [string length $indent]
       } elseif {([string length $line] == 0) && ([llength $numIndentChars] > 0)} {
          # Blank line--use the previous indent level
          lappend numIndentChars [lindex $numIndentChars end]
       } else {
          lappend numIndentChars 0
       }
    }

    # The first line dictates the mininum indent level
    set minIndent [lindex $numIndentChars 0]
    set temp {}
    foreach indent $numIndentChars {
        if {$indent < $minIndent} {
            lappend temp $minIndent
        } else {
            lappend temp $indent
        }
    }
    set numIndentChars $temp

    # Create the tree if one wasn't passed in
    if {[string length $tree] == 0} {
       set tree [struct::tree]
       namespace export [namespace tail $tree]
       namespace eval :: "namespace import $tree"
       $tree set [$tree rootname] expand 1
    }
    set indentLevels [lsort -integer -unique $numIndentChars]
    for {set x 0} {$x < [$tree depth $node]} {incr x} {
       set indentLevels [concat [list {}] $indentLevels]
    }

    # Insert each line into the tree
    set curParent $node
    set idx $startIdx
    foreach line [split $string \n] indent $numIndentChars {
       set level [lsearch $indentLevels $indent]
       if {$level > [$tree depth $curParent]} {
           set curParent [lindex [$tree children $curParent] [expr $idx - 1]]
           set idx 0
       } else {
           while {$level < [$tree depth $curParent]} {
              set idx [expr [$tree index $curParent] + 1]
              set curParent [$tree parent $curParent]
           }
       }
       set node [$tree insert $curParent $idx] 
       $tree set $node title [string trimleft $line]
       incr idx
       set lastNode $node
    }
    return [namespace tail $tree]
}
proc opmlToIndentedText {xml} {
    package require dom     ;# tcldom
    set d [dom::parse $xml]
    set output ""
    foreach node [dom::selectNode $d //outline] {
        set parent [dom::node cget $node -parentNode]
        set depth 0
        while {[string length $parent] > 0} {
            incr depth
            set parent [dom::node cget $parent -parentNode]
        }
        set indent [string repeat "    " $depth]
        lappend output "$indent[dom::element getAttribute $node text]"
    }
    return [join $output \n]
 }
 proc opmlToTree {opml} {return [textToTree [opmlToIndentedText $opml]]}
 proc indentedasciiToTree {text} {return [textToTree $text]}
}
package provide treeconvert 1.0
