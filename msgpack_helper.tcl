namespace eval ::msgpack {
    namespace export *
    namespace ensemble create

    proc map2dict {m} {
	set d [dict create]
	foreach {ki vi} $m {
	    lassign $ki kt kv
	    lassign $vi vt vv
	    dict set d $kv $vv
	}
	return $d
    }

    proc map2array {m anm} {
	upvar $anm a
	foreach {ki vi} $m {
	    lassign $ki kt kv
	    lassign $vi vt vv
	    set a($kv) $vv
	}
    }

    proc array2list {a} {
    }
}

