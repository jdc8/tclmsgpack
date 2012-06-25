package require critcl 3

namespace eval ::msgpack {
}

critcl::license {Jos Decoster} {Apache License V2.0 / BSD}
critcl::summary {Binary-based efficient object serialization library}
critcl::description {
    msgpack is a Tcl binding for the MessagePack library (http://msgpack.org/), 
    a binary-based efficient object serialization library.
}
critcl::subject MessagePack msgpack serialization

critcl::meta origin https://github.com/jdc8/tclmsgpack

critcl::userconfig define mode {choose mode of ZMQ to build and link against.} {static dynamic}

if {[string match "win32*" [::critcl::targetplatform]]} {
} else {
    switch -exact -- [critcl::userconfig query mode] {
	static {
	    critcl::clibraries -l:libmsgpack.a
	}
	dynamic {
	    critcl::clibraries -lmsgpack
	}
    }
}
#critcl::cflags -ansi -pedantic -Wall


# Get local build configuration
if {[file exists "[file dirname [info script]]/zmq_config.tcl"]} {
    set fd [open "[file dirname [info script]]/zmq_config.tcl"]
    eval [read $fd]
    close $fd
}

critcl::tcl 8.5
critcl::tsources msgpack_helper.tcl

critcl::ccode {
#include "msgpack.h"
}

critcl::ccommand ::msgpack::version {cd ip objc objv} {
    Tcl_SetObjResult(ip, Tcl_NewStringObj(msgpack_version(), -1));
    return TCL_OK;
}

critcl::cinit {} {}

package provide msgpack 1.0

