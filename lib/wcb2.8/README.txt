                    The Widget Callback Package Wcb

                                   by

                             Csaba Nemethi

                       csaba.nemethi@t-online.de 


What is Wcb?
------------

Wcb is a library package for Tcl/Tk version 8.0 or higher, written in
pure Tcl/Tk code.  It contains a few commands providing a simple and
GENERAL solution to problems like the following:

  - How to restrict the set of characters that the user can type or
    paste into an entry, spinbox, or text widget?
  - How to manipulate the user input characters before they are
    inserted into an entry, spinbox, or text widget?  In the case of a
    text widget:  How to change the font, colors, or other attributes
    of the input characters?
  - How to set a limit for the number of characters that can be typed
    or pasted into an entry or spinbox widget?
  - How to protect some parts of the text contained in an entry,
    spinbox, or text widget from being changed by the user?
  - How to define notifications to be triggered automatically after
    text is inserted into or deleted from an entry, spinbox, or text
    widget?
  - How to define some actions to be invoked automatically whenever the
    insertion cursor in an entry, spinbox, or text widget is moved?
  - How to define a command to be called automatically when selecting a
    listbox element or a range of characters in a text widget?
  - How to protect any or all items of a listbox or a range of
    characters in a text widget from being selected?

In most books, FAQs, newsgroup articles, and widget sets, you can find
INDIVIDUAL solutions to some of the above problems by means of widget
bindings.  This approach quite often proves to be incomplete.  The
solutions provided by more recent versions of the Tk core to some of
these problems are also of INDIVIDUAL nature.

The package Wcb goes a completely different way:  Based on redefining
the Tcl command corresponding to a widget, the main Wcb procedure
"callback" enables you to associate arbitrary commands with some entry,
spinbox, listbox, tablelist (see http://www.nemethi.de), and text
widget operations.  These commands will be invoked automatically in the
global scope whenever the respective widget operation is executed.  You
can request that these commands be called either before or after
executing the respective widget operation, i.e., you can define both
before- and after-callbacks.  From within a before-callback, you can
cancel the respective widget command by invoking the procedure
"cancel", or modify its arguments by calling "extend" or "replace".

Besides these (and four other) general-purpose commands, the Wcb
package exports three utility procedures for entry and spinbox widgets,
as well as ready-to-use before-insert callbacks for entry, spinbox, and
text widgets.

How to get it?
--------------

Wcb is available for free download from the Web page

    http://www.nemethi.de

The distribution file is "wcb2.8.tar.gz" for UNIX and "wcb2_8.zip" for
Windows.  These files contain the same information, except for the
additional carriage return character preceding the linefeed at the end
of each line in the text files for Windows.

How to install it?
------------------

Install the package as a subdirectory of one of the directories given
by the "auto_path" variable.  For example, you can install it as a
directory at the same level as the Tcl and Tk script libraries.  The
locations of these library directories are given by the "tcl_library"
and "tk_library" variables, respectively.

To install Wcb on UNIX, "cd" to the desired directory and unpack the
distribution file "wcb2.8.tar.gz":

    gunzip -c wcb2.8.tar.gz | tar -xf -

This command will create a directory named "wcb2.8", with the
subdirectories "demos", "doc", and "scripts".

On Windows, use WinZip or some other program capable of unpacking the
distribution file "wcb2_8.zip" into the directory "wcb2.8", with the
subdirectories "demos", "doc", and "scripts".

How to use it?
--------------

To be able to use the commands and variables implemented in the package
Wcb, your scripts must contain one of the lines

    package require Wcb
    package require wcb

Since the package Wcb is implemented in its own namespace called "wcb",
you must either import the procedures you need, or use qualified names
like "wcb::callback".

For a detailed description of the commands and variables provided by
Wcb and of the examples contained in the "demos" directory, see the
manual file "wcb.html" in the "doc" directory.
