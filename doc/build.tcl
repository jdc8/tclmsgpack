package require doctools

set on [doctools::new on -format html]
set f [open msgpack.html w]
puts $f [$on format {[include msgpack.man]}]
close $f

$on destroy
