## ButtonBar.tcl
##
## Creates a button bar.  Specifically, it:
## * creates a frame called ".buttonbar" 
## * creates a bunch of buttons
## * packs the buttons onto the frame
## * then packs the frame onto the top level window
##
## So, you should source this file at exactly the point where you want to
## pack the button bar into the top level window.
##
## Add buttons by modifying the list "Buttons".  The format is:
## {Name} {gif} {command}


package require BWidget
package require icons
namespace eval tkoutline {
set icondir [file dirname [info script]]
::icons::icons create -group * -file [file join $icondir tkIcons.klassic]

set Buttons {
New 				{::icon::filenew22} 	{event generate [focus -lastfor .] <<New>>}
Open 				{::icon::fileopen22}	{event generate [focus -lastfor .] <<Open>>}
Save				{::icon::filesave22}	{event generate [focus -lastfor .] <<Save>>}
| 					{}						{}
{Duplicate Node}	{::icon::editcopy22} 	{event generate [focus -lastfor .] <<DuplicateNode>>}
{Delete Node}		{::icon::editdelete22} 	{event generate [focus -lastfor .] <<DeleteNode>>}
| 					{}						{}
{Move Up}			{::icon::navup22} 	{event generate [focus -lastfor .] <<NodeUp>>}
{Move Down}			{::icon::navdown22} 	{event generate [focus -lastfor .] <<NodeDown>>}
{Promote}			{::icon::navback22} 	{event generate [focus -lastfor .] <<Promote>>}
{Demote}			{::icon::navforward22} 	{event generate [focus -lastfor .] <<Demote>>}
| 					{}						{}
}



## You can define a global variable "::tkoutline::GifFolder" outside this file.
## The ::tkoutline::GifFolder path is joined to each gif specified in the Buttons list
## to locate the image file.
if {![info exists ::tkoutline::GifFolder]} {
	set ::tkoutline::GifFolder {}
}

proc AddButton {Path Name Gif Command} {
    variable separatorCount
    if {$Name == "|"} {
        set Name "Sep$separatorCount"
        Separator "$Path.but[string map {{ } {}} $Name]" -orient vertical -relief ridge
        incr separatorCount
    } else {
        Button "$Path.but[string map {{ } {}} $Name]" \
            -image $Gif \
            -command $Command \
            -relief link \
            -helptype balloon \
            -helptext $Name \
            -bd 1
            # -image [image create photo -file [file join $::tkoutline::GifFolder $Gif]] \
            
    }
        
    pack "$Path.but[string map {{ } {}} $Name]" \
        -side left \
        -padx 1
}

proc CreateButtonBar {Path lst_Buttons} {
    variable separatorCount 0

	foreach {Name Gif Command} $lst_Buttons {
        AddButton $Path $Name $Gif $Command
	}	
}
}
