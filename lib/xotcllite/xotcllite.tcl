if 0 { 

[Brian Theado] 04Aug03 -
[Thingy: a one-liner OO system] implements an object system that reminds me of [XOTcl] objects.  Here I take a stab at adding classes to thingy.  Functionality is shared between the various objects and classes by using the [namespace] import functionality.

[XOTcl] has two main commands: Object and Class.  The Object command creates objects and the Class command creates object creator commands.  These object creator commands can have methods (instprocs) attached to them.

[XOTcl] has a wealth of features few of which are implemented here. No inheritance, no filters, no mixins, etc.

[Thingy: a one-liner OO system] inspires the following function that behaves very similar to [XOTcl]'s Object command.

}
namespace eval xotcllite {
    namespace export Object Class
}
proc xotcllite::createPrimitiveObject name {
    if {[string range $name 0 1] != "::"} {
        set name [string map {:::: ::} [uplevel 1 namespace current]::$name]
    }
    proc $name args "namespace eval $name \$args"
    return $name
}

# The procedures in the objectmethods namespace will be inherited by all objects
 namespace eval xotcllite::objectmethods {}
 
if 0 {
Procedures always execute within the namespace in which they are defined 
even when they are imported into other namespaces.  In order to find which 
namespace the procedure was actually called from, a combination of ''uplevel'' 
and ''namespace which'' can do the trick.  Thanks to [Mark G. Saye] on c.l.t 
[http://groups.google.com/groups?dq=&hl=en&lr=&ie=UTF-8&selm=3F2D7190.6080405%40yahoo.com]
 for this tip.
}
 proc xotcllite::objectmethods::self {} {
    # Case 1: namespace eval Object --> somemethod --> self
    set proc [lindex [info level -1] 0]
    set level 2
    if {$proc == "namespace"} {
        # Case2: namespace eval Object --> self
        incr level -1
        set proc [lindex [info level 0] 0]
    }
    return [namespace qualifiers [uplevel $level [list namespace which -command $proc]]]
 }
 proc xotcllite::objectmethods::my {args} {
    uplevel {[self]} $args
 }
 proc xotcllite::objectmethods::destroy {} {
    set self [self]
    namespace delete $self
    rename $self ""
 }
 namespace eval xotcllite::objectmethods {namespace export *}

# The procedures in classmethods will be inherited by all class objects and should include all the object procedures as well
 namespace eval xotcllite::classmethods "namespace import [namespace current]::xotcllite::objectmethods::self"
 proc xotcllite::classmethods::create {name args} {
    set name [uplevel 3 ::xotcllite::createPrimitiveObject $name]
    namespace eval [self]::instprocs {} ;# Make sure the namespace exists
    $name namespace import [self]::instprocs::* 
    if {[llength [info commands ${name}::init]] > 0} {
        return [eval $name init $args]
    } else {
        return $name
    }
 }
 proc xotcllite::classmethods::instproc {name arglist body} {
    namespace eval [self]::instprocs {} ;# Make sure the namespace exists
    proc [self]::instprocs::$name $arglist $body
    namespace eval [self]::instprocs "namespace export $name"
 }
 namespace eval xotcllite::classmethods {namespace export *}

if 0 {
    An object is-a class

    The child namespace "instproc" is used to store those methods that will be inherited by instances
}
 xotcllite::createPrimitiveObject xotcllite::Object
 namespace eval xotcllite::Object "
    namespace import [namespace current]::xotcllite::objectmethods::*
    namespace import -force [namespace current]::xotcllite::classmethods::*
    "
 namespace eval xotcllite::Object::instprocs "
    namespace import [namespace current]::xotcllite::objectmethods::*
    namespace export *
    " 

if 0 {
   * Class is an object that creates classes
   * Class should itself be a class
   * A class is an object that creates objects with a pre-defined set of methods
   * Not sure if I have this right (the way xotcl does it).  Thinking about it is making my head spin.  The behavior of some simple examples seems ok.
}
 xotcllite::createPrimitiveObject xotcllite::Class
 namespace eval xotcllite::Class "
    namespace import [namespace current]::xotcllite::objectmethods::*
    namespace import -force [namespace current]::xotcllite::classmethods::*
    "
 namespace eval Class::instprocs "
    namespace import [namespace current]::xotcllite::objectmethods::*
    namespace import -force [namespace current]::xotcllite::classmethods::*
    namespace export *
    " 
if 0 {
  Create for the Class object is slightly different--it must also
  propagate the object methods to the created class's instproc namespace,
  so override it's definition here.
}
 xotcllite::Class proc create name {
    set newClass [uplevel 3 ::xotcllite::Object create $name]
    namespace eval $newClass {
        namespace import -force ::xotcllite::classmethods::*
    }
    namespace eval ${newClass}::instprocs {
        namespace import ::xotcllite::objectmethods::*
        namespace export *
    }
    return $newClass
 }

if 0 {
Features that would be nice to have:
  * Lot's more introspection
  * Automatic propagation of new instprocs to existing instances
  * Ability to define procs and instprocs called "unknown" to behave like Tcl's global unknown procedure.  This would allow for easy delegation functionality
  * Constructors via init

Example code:
 Class create Bagel
 Bagel create abagel
 abagel self
 abagel set toasted 0
 abagel info vars
 info vars abagel::*
 abagel set toasted
 abagel destroy
 Bagel instproc toast {} {
    [self] incr toasted
    if {[[self] set toasted] > 1} {
        error "something's burning!"
    }
    return
 }
 Bagel create abagel
 abagel set toasted 0
 abagel toast
 abagel toast

See also [another minimal Tcl object system (XOTcl like syntax)]
----
[Category Object Orientation]
}
package provide XOTcllite 0.1
