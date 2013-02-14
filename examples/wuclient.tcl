#
# Weather update client
# Connects SUB socket to tcp:#localhost:5556
# Collects weather updates and finds avg temp in zipcode
#

package require zmq
package require msgpack

# Socket to talk to server
zmq context context
zmq socket subscriber context SUB
subscriber connect "tcp://localhost:5556"

# Subscribe to zipcode, default is NYC, 10001
if {[llength $argv]} {
    set filter [lindex $argv 0]
} else {
    set filter "10001"
}

subscriber setsockopt SUBSCRIBE "" ;# $filter

# Process updates
set total_temp 0
for {set update_nbr 0} {$update_nbr < 10} {} {
    zmq message msg
    subscriber recv_msg msg
    set data [msgpack map2dict [lindex [msgpack unpack [msg data]] 0 1]]
    msg close
    if {[dict get $data zipcode] == $filter} {
	puts $data
	incr total_temp [dict get $data temperature]
	incr update_nbr
    }
}

puts "Averate temperatur for zipcode $filter was [expr {$total_temp/$update_nbr}]F"

subscriber destroy
context destroy
