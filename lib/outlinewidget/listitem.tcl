# Tkoutline - an outline editor.
# Copyright (C) 2002  Brian P. Theado
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
namespace eval listitem {
namespace export *

# Get item at the given text widget index
proc itemAtIdx {win idx} {
    set tags [$win tag names $idx]
    if {[set idx [lsearch -regexp $tags {item:}]] >= 0} {
	return [string range [lindex $tags $idx] 5 end]
    }
    return ""
}
proc itemsWithTag {win tag} {
    set items {}
    foreach {startIdx endIdx} [$win tag ranges $tag] {
        set item [itemAtIdx $win $startIdx]
        lappend items $item
        while {[$win compare item:$item.last < $endIdx]} {
            set item [next $win $item]
            if {[string length $item] > 0} {
                lappend items $item
            } else {
                break
            }
        }
    }
    return $items
}

proc prev {win item} {
    set prev [itemAtIdx $win item:$item.first-1c]
    if {"$prev" == "$item"} {return {}}
    return $prev
}
proc next {win item} {
    set next [itemAtIdx $win item:$item.last+1c]
    if {"$next" == "$item"} {return {}}
    return $next
}
proc exists {win item} {
    return [expr [llength [$win tag ranges item:$item]] > 0]
}

# TODO: Should field tags have a "field:" prefix?
proc createItem {args} {
    set twText {}
    foreach {item fieldList extraTags} $args {
        set len [expr [llength $fieldList] / 2]
        set x 1
        lappend extraTags * item:$item
        foreach {field textAndTags} $fieldList {nextField ignore} [lrange $fieldList 2 end] {
            set text [lindex $textAndTags 0]
            set tags [lindex $textAndTags 1]
            foreach {patternList extra} $extraTags {
                foreach pattern $patternList {
                    if {[string match $pattern $field]} {
                        set tags [concat $tags $extra]
                    }
                }
            }
            set tags [concat $field $tags]
            if {$x < $len} {
                lappend twText "$text" $tags " " [concat $tags $nextField fieldsep readonly]
            } else {
                lappend twText $text $tags \n [concat $tags fieldsep readonly]
            }
            incr x
        }
    }
    return $twText
}

proc insert {win idx args} {
    #eval [list $win insert $idx] $args
    eval [list $win insert $idx] [eval createItem $args]
}
proc delete {win firstItem {lastItem ""}} {
    set firstIdx [index $win $firstItem.first]
    if {[string length $lastItem] > 0} {
        set lastIdx [index $win $lastItem.last]
    } else {
        set lastIdx [index $win $firstItem.last]
    }
    $win tag remove readonly $firstIdx $lastIdx
    $win delete $firstIdx $lastIdx 
}
proc getField {win item fieldName} {
    return [$win get [index $win $item.$fieldName.first] \
                     [index $win $item.$fieldName.last]]
}
proc setField {win item fieldName value} {
    set idx [index $win $item.$fieldName.last]
    $win insert $idx $value
    $win delete [index $win $item.$fieldName.first] $idx
}

# TODO: can be simplified to just lsearch [tag names]
proc isIdxInField {win field idx} {
    set node [itemAtIdx $win $idx]
    if {[string length $node] > 0} {
        return [expr \
            [$win compare $idx >= [index $win $node.$field.first]] && \
            [$win compare $idx <= [index $win $node.$field.last]]]
    } else {
        return 0
    }
}

# Returns the numeric text widget index corresponding to the given index
proc index {win index} {
    set index [split $index .]
    if {[llength $index] >= 3} {
        set item [join [lrange $index 0 end-2] .]
        set field [lindex $index end-1]
        set firstOrLast [lindex $index end]
        set range [$win tag nextrange $field item:$item.first]
        if {[llength $range] > 0} {
            switch $firstOrLast {
                first {
                    set retIdx [lindex $range 0]
                    if {[lsearch [$win tag names $retIdx] fieldsep] >= 0} {
                        set retIdx [$win index $retIdx+1c]
                    }
                }
                last {
                    set retIdx [$win index [lindex $range 1]-1c]
                }
                default {
                    error "Index error.  TODO: better error message"
                }
            }
            # TODO: verify retIdx is within the given items range
            return $retIdx
        } else {
            # Normal text widget index syntax
            if {[catch {$win index [join $index .]} idx]} {
                return [$win index item:[join $index .]]
            } else {
                return $idx
            }
        }
    } else {
        # Normal text widget index syntax
        if {[catch {$win index [join $index .]} idx]} {
            return [$win index item:[join $index .]]
        } else {
            return $idx
        }
    }
}
}
