# wikimarkup.tcl --
#
#     Tk text widget yntax highlighting rules for wiki markup
#
# Copyright (C) 2002  Brian P. Theado
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
package require markup
namespace eval wikimarkup {
    namespace export addWikiRules setLinkJumpCmd enableStyleMarkup disableStyleMarkup enableUrlMarkup disableUrlMarkup enableWikilinkMarkup disableWikiLinkMarkup enableIbisMarkup disableIbisMarkup

proc findExecutable {progname} {
    global env
    set progs [auto_execok $progname]
    if {[llength $progs]} {
        set env(BROWSER) [lindex $progs 0]
    }
    return [llength $progs]
}

# Code based off the code at http://mini.net/tcl/557.html
proc launchUrl {url} {
    global tcl_platform env
    switch $tcl_platform(platform) {
        "unix" {
            expr {
                [info exists env(BROWSER)] ||
		        [findExecutable mozilla] ||
                [findExecutable netscape] ||
                [findExecutable iexplorer] ||
                [findExecutable $env(NETSCAPE)] ||
                [findExecutable lynx]
            }
            # lynx can also output formatted text to a variable
            # with the -dump option, as a last resort:
            # set formatted_text [ exec lynx -dump $url ] - PSE
            if {[catch {exec $env(BROWSER) -remote $url}]} {
                # perhaps browser doesn't understand -remote flag
                if {[catch {exec $env(BROWSER) $url &}]} {
                    # Try again for the case where env(BROWSER) contains a command plus some args
                    if {[catch {eval exec $env(BROWSER) [list $url] &} emsg]} {
                        error "Error displaying $url in browser\n$emsg"
                        # Another possibility is to just pop a window up
                        # with the URL to visit in it. - DKF
                    }
                }
            }
        }
        "windows" {
            # The windows NT shell treats '&' as a special character.  Using
            # a '^' will escape it
            if {[string compare $tcl_platform(os) "Windows NT"] == 0} {
                set url [string map {& ^&} $url]
            }
            eval exec [auto_execok start] [list $url] &
            }

        "macintosh" {
            if {0 == [info exists env(BROWSER)]} {
                set env(BROWSER) "Browse the Internet"
            }
            if {[catch {
                AppleScript execute\
                    "tell application \"$env(BROWSER)\"
                         open url \"$url\"
                     end tell
                "} emsg]
            } then {
                error "Error displaying $url in browser\n$emsg"
            }
        }
    } ;## end of switch 
}

# Splits a link into its link portion and anchor portion
proc linkSplit {linkText} {
    set splitList [split $linkText #]
    return [list [lindex $splitList 0] [join [lrange $splitList 1 end] #]]
}

# Returns the text of a link at the given idx that is marked by the given tag
proc getLinkText {win tag idx} {
    # Get the text marked by the tag
    set linkText [eval $win get [::markup::getTagRange $win $tag $idx]]

    # Trim off the braces
    set linkText [string range $linkText 1 end-1]
    return $linkText
}
proc onWikiLinkClick {win tag idx script} {
    set linkText [::wikimarkup::getLinkText $win $tag $idx]
    $win mark set insert $idx
    eval [concat $script [linkSplit $linkText]]
}

# Sets the script to execute when a wiki-link is clicked
proc setLinkJumpCmd {win script} {
    # Don't do the wiki link jump immediately upon button press.  Otherwise,
    # the insertion cursor won't end up on the destination for a link that
    # jumps within the same outline to somewhere off the screen.  The reason
    # is because when the jump takes place immediately due to a tag binding,
    # the normal window bindings will be fired and the mouse will no longer
    # be over a wikilink tag (when the mouse is over a wikilink tag, a
    # break is called before the Text binding can be called).  So the insertion
    # cursor ends up at the same screen position as when the link was clicked,
    # instead of on the target of the search
    # This still has the problem, that if the insertion cursor is off-screen
    # and an intra-outline link is clicked, the jump doesn't take place.  The
    # user has to click again for the jump.  This one has me puzzled
    $win tag bind wikilink <ButtonPress> "after idle [list ::wikimarkup::onWikiLinkClick $win wikilink @%x,%y [list $script]]; break"

    # There are no intra-outline jumps for empty links, so the action can be
    # taken when the event occurs
    $win tag bind emptylink <ButtonPress> "[list ::wikimarkup::onWikiLinkClick $win emptylink @%x,%y $script]; break"

    # Tag bindings only fire on the "current" (which is where the mouse is).
    # This doesn't do much good for keystrokes, so bind to the whole widget
    # and manually check if the insertion cursor has the wikilink tag
    bind $win <Control-j> [subst {
        if {\[lsearch \[%W tag names insert] wikilink] >= 0} {
            ::wikimarkup::onWikiLinkClick %W wikilink insert [list $script]
        } elseif {\[lsearch \[%W tag names insert] emptylink] >= 0} {
            ::wikimarkup::onWikiLinkClick %W emptylink insert [list $script]
        }
    }]
}

# Set multiple variable from a list
proc mset {vars list} {
    uplevel foreach [list $vars] [list $list] break
}

# Callback for when a wiki link is detected    
proc markupWikiLink {win startIdx endIdx} {
    set linkText [$win get $startIdx+1c $endIdx-1c]
    mset {link anchor} [linkSplit $linkText]
    if {([string length $link] == 0) && ([string length $anchor] > 0)} {
        # Link portion is empty, so search within the outline
        set textTag wikilink
        set braceTag linkbrace
    } else {
        set match [glob -nocomplain $link]
        if {(([llength $match] == 1) && ([file exists [lindex $match 0]])) ||
                ([llength $match] > 1)} {
            # The above test is more complicated than it needs to be in order 
            # to work around a bug in mk4::vfs.  For some reason if a wiki link
            # is internal to a starkit, then a glob without patterns
            # within an mk4 vfs mount always returns that string.  File exists
            # works correctly, though.
            set textTag wikilink
            set braceTag linkbrace
        } else {
            set textTag emptylink
            set braceTag emptylinkbrace
        }
    }
    $win tag add $textTag $startIdx $endIdx
    $win tag add $braceTag $startIdx
    $win tag add $braceTag $endIdx-1c
    return [list $textTag $braceTag]
}

# Callback for when a style pattern is detected
proc markupStyle {win startIdx endIdx} {
    set startIdx [$win search -elide -regexp {[^[:space:]]} $startIdx $endIdx]
    set endIdx [$win search -elide -backwards -regexp {[^[:space:]]} $endIdx $startIdx]
    switch -- [$win get $startIdx] {
        * {set tag bold}
        / {set tag italic}
        _ {set tag underline}
        - {set tag overstrike}
    }
    $win tag add $tag $startIdx $endIdx
    $win tag add hidden $startIdx
    $win tag add hidden $endIdx
    return [list $tag hidden]
}

proc markupIbis {win startIdx endIdx} {
        switch -- [$win get $startIdx+1c] {
            ? {set tag how}
            # {set tag idea}
            + {set tag pro}
            - {set tag con}
        }
        $win tag add $tag $startIdx+1c
        $win tag add ibis $startIdx+1c
        return [list $tag ibis]
}

proc configureEmptyLinkTag {win} {
    $win tag configure emptylinkbrace -foreground blue
    $win tag bind emptylink <Any-Enter> "
        $win tag raise brightlink 
        set indices \[::markup::getTagRange $win emptylink @%x,%y]
        $win tag add brightlink \[lindex \$indices 0]
        $win tag add brightlink \[lindex \$indices 1]-1c
        $win tag bind emptylink <Any-Leave> \"
            $win tag remove brightlink \[lindex \$indices 0]
            $win tag remove brightlink \[lindex \$indices 1]-1c
            $win configure -cursor xterm\"
        $win configure -cursor hand2
        "
}
proc disableWikiLinkMarkup win {
    variable wikiLinkRe
    markup::removeRule $win $wikiLinkRe
    }
proc enableWikiLinkMarkup win {
    variable wikiLinkRe

    # Configure empty wiki link tags
    configureEmptyLinkTag $win

    # Configure wiki link tags
    $win tag configure linkbrace -elide 1
    $win tag configure wikilink -foreground blue
    $win tag configure brightlink -foreground red
    ::markup::flashTag $win wikilink brightlink
    $win tag bind wikilink <Enter> "+$win configure -cursor hand2"
    $win tag bind wikilink <Leave> "+$win configure -cursor xterm"
    $win tag configure hidden -elide 1

    # Prevent Text class bindings from firing when a wiki link is clicked (This
    # is for an anchor tag that jumps within the outline.  Simply using "break"
    # within the tag binding doesn't work.
    bind wikimarkup <1> {
        if {[lsearch [%W tag names @%x,%y] wikilink] >= 0} break
    }
    bindtags $win [linsert [bindtags $win] 1 wikimarkup]

    # Add the syntax highlighting rule
    set wikiLinkRe {\[[^%\[\]+-]+[^%\[\]]*\]}
    markup::addRule $win \
        -regexp $wikiLinkRe \
        -callback ::wikimarkup::markupWikiLink
}
# Callback for when a wiki link is detected    
proc markupMagicButton {win startIdx endIdx} {
    $win tag add button $startIdx $endIdx
    $win tag add hidden $startIdx $startIdx+2c
    $win tag add hidden $endIdx-2c $endIdx
    return [list button hidden]
}
proc enableMagicButtonMarkup win {
    # Add the syntax highlighting rule
    set magicButtonRe {\[%[^\[\]+-]+[^\[\]]*%\]}
    markup::addRule $win \
        -regexp $magicButtonRe \
        -callback ::wikimarkup::markupMagicButton
}
proc disableUrlMarkup win {
    variable urlRe
    markup::removeRule $win $urlRe
    }
proc enableUrlMarkup win {
    variable urlRe

    # Configure url tags
    $win tag configure url -foreground blue
    ::markup::flashTag $win url brightlink
    $win tag bind url <Enter> "+$win configure -cursor hand2"
    $win tag bind url <Leave> "+$win configure -cursor xterm"
    $win tag bind url <ButtonPress> "::wikimarkup::launchUrl \[eval $win get \[::markup::getTagRange $win url @%x,%y]]"

    # Add the syntax highlighting rule
    set urlRe {\m(https?|ftp|file|news|mailto):(\S+[^\]\)\s\.,!\?;:'>])}
    markup::addRule $win \
        -regexp $urlRe \
        -tag url
}
proc disableStyleMarkup win {
    variable styleRe
    markup::removeRule $win $styleRe
    }
proc enableStyleMarkup win {
    variable styleRe

    # Configure the tags
    set font [$win cget -font]
    foreach tag {bold italic underline overstrike} {
        $win tag configure $tag -font [concat $font $tag]
    }
    $win tag configure hidden -elide 1

    # Regexp for bold, italics, etc.
    set styleRe {(?:^|[[:space:]])([*/\-_])[^[:space:]].*?[^[:space:]]\1(?:$|[[:space:]])} 
    
    # When a regexp contains a branch, it defaults to longest match.  The
    # following forces shortest match
    set styleRe "(?:$styleRe){1,1}?" 
    markup::addRule $win \
        -regexp $styleRe \
        -callback ::wikimarkup::markupStyle
}
proc disableIbisMarkup win {
    variable ibisRe
    markup::removeRule $win $ibisRe
    }
proc enableIbisMarkup win {
    variable ibisRe

    # Help for "design thinking" notes
    $win tag configure how -background green
    $win tag configure idea -background cyan
    $win tag configure pro -background yellow
    $win tag configure con -background red
    $win tag configure ibis -font {Courier 10}
    set ibisRe { [?#+\-] }
    markup::addRule $win -regexp $ibisRe -callback ::wikimarkup::markupIbis
}
proc addWikiRules {win {markupList {wikilinks urls style}}} {
    if {[lsearch $markupList style] >= 0} {
        enableStyleMarkup $win
        }
    enableMagicButtonMarkup $win
    if {[lsearch $markupList wikilinks] >= 0} {
        enableWikiLinkMarkup $win
        }
    if {[lsearch $markupList urls] >= 0} {
        enableUrlMarkup $win
        }

    if {[lsearch $markupList ibis] > 0} {
        enableIbisMarkup $win
        }

    # Automatically detect patterns as text is inserted
    markup::enableHighlighting $win 
}
}
package provide wikimarkup 0.1
