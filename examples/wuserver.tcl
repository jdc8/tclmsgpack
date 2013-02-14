#
# Weather update server
# Binds PUB socket to tcp:#*:5556
# Publishes random weather updates
#

package require zmq
package require msgpack

# Prepare our context and publisher
zmq context context

zmq socket publisher context PUB
publisher bind "tcp://*:5556"
if {$::tcl_platform(platform) ne "windows"} {
    publisher bind "ipc://weather.ipc"
}

# Initialize random number generator
expr {srand([clock seconds])}

while {1} {
    # Get values that will fool the boss
    set zipcode [expr {int(rand()*100000)}]
    set temperature [expr {int(rand()*215)-80}]
    set relhumidity [expr {int(rand()*50)+50}]
    # Send message to all subscribers
    msgpack packer p
    set data [dict create zipcode $zipcode temperature $temperature relhumidity $relhumidity]
    p pack dict string int $data
    if {$zipcode eq "10001"} {
	puts $data
    }
    zmq message msg -data [p data]
    publisher send_msg msg
    msg destroy
    p destroy
    update idletasks
}

publisher destroy
context destroy
