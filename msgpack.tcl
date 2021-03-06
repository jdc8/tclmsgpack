package require critcl 3

namespace eval ::msgpack {
}

critcl::license {Jos Decoster} {BSD}
critcl::summary {Binary-based efficient object serialization library}
critcl::description {
    msgpack is a Tcl binding for the MessagePack library (http://msgpack.org/),
    a binary-based efficient object serialization library.
}
critcl::subject MessagePack msgpack serialization

critcl::meta origin https://github.com/jdc8/tclmsgpack

critcl::userconfig define mode {choose mode of MsgPack to build and link against.} {static dynamic}

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
if {[file exists "[file dirname [info script]]/msgpack_config.tcl"]} {
    set fd [open "[file dirname [info script]]/msgpack_config.tcl"]
    eval [read $fd]
    close $fd
}

critcl::tcl 8.5
critcl::tsources msgpack_helper.tcl

critcl::ccode {

#include "msgpack.h"

    typedef struct {
	int id;
    } MsgpackClientData;

    typedef struct {
	Tcl_Obj* tcl_cmd;
	struct msgpack_sbuffer* sbuf;
	struct msgpack_packer* pk;
    } MsgpackPackerClientData;

    static void msgpack_free_client_data(void* p) { ckfree(p); }

    static Tcl_Obj* unique_namespace_name(Tcl_Interp* ip, Tcl_Obj* obj, MsgpackClientData* cd) {
	Tcl_Obj* fqn = 0;
	if (obj) {
	    const char* name = Tcl_GetStringFromObj(obj, 0);
	    Tcl_CmdInfo ci;
	    if (!Tcl_StringMatch(name, "::*")) {
		Tcl_Eval(ip, "namespace current");
		fqn = Tcl_GetObjResult(ip);
		fqn = Tcl_DuplicateObj(fqn);
		Tcl_IncrRefCount(fqn);
		if (!Tcl_StringMatch(Tcl_GetStringFromObj(fqn, 0), "::")) {
		    Tcl_AppendToObj(fqn, "::", -1);
		}
		Tcl_AppendToObj(fqn, name, -1);
	    } else {
		fqn = Tcl_NewStringObj(name, -1);
		Tcl_IncrRefCount(fqn);
	    }
	    if (Tcl_GetCommandInfo(ip, Tcl_GetStringFromObj(fqn, 0), &ci)) {
		Tcl_Obj* err;
		err = Tcl_NewObj();
		Tcl_AppendToObj(err, "command \"", -1);
		Tcl_AppendObjToObj(err, fqn);
		Tcl_AppendToObj(err, "\" already exists, unable to create object", -1);
		Tcl_DecrRefCount(fqn);
		Tcl_SetObjResult(ip, err);
		return 0;
	    }
	}
	else {
	    Tcl_Eval(ip, "namespace current");
	    fqn = Tcl_GetObjResult(ip);
	    fqn = Tcl_DuplicateObj(fqn);
	    Tcl_IncrRefCount(fqn);
	    if (!Tcl_StringMatch(Tcl_GetStringFromObj(fqn, 0), "::")) {
		Tcl_AppendToObj(fqn, "::", -1);
	    }
	    Tcl_AppendToObj(fqn, "msgpack", -1);
	    Tcl_AppendPrintfToObj(fqn, "%d", cd->id);
	    cd->id = cd->id + 1;
	}
	return fqn;
    }

    enum PackerTypes {PACKTYPE_SHORT, PACKTYPE_INT, PACKTYPE_LONG, PACKTYPE_LONG_LONG,
		      PACKTYPE_USHORT, PACKTYPE_UINT, PACKTYPE_ULONG, PACKTYPE_ULONG_LONG,
		      PACKTYPE_INT8, PACKTYPE_INT16, PACKTYPE_INT32, PACKTYPE_INT64,
		      PACKTYPE_UINT8, PACKTYPE_UINT16, PACKTYPE_UINT32, PACKTYPE_UINT64,
		      PACKTYPE_FIX_INT8, PACKTYPE_FIX_INT16, PACKTYPE_FIX_INT32, PACKTYPE_FIX_INT64,
		      PACKTYPE_FIX_UINT8, PACKTYPE_FIX_UINT16, PACKTYPE_FIX_UINT32, PACKTYPE_FIX_UINT64,
		      PACKTYPE_FLOAT, PACKTYPE_DOUBLE,
		      PACKTYPE_NIL, PACKTYPE_TRUE, PACKTYPE_FALSE, PACKTYPE_BOOL,
		      PACKTYPE_ARRAY, PACKTYPE_MAP, PACKTYPE_LIST, PACKTYPE_DICT, PACKTYPE_TCLARRAY,
		      PACKTYPE_RAW, PACKTYPE_RAW_BODY, PACKTYPE_STRING};

    static int get_pack_type(Tcl_Interp* ip, Tcl_Obj* o, int* tindex)
    {
	static const char* pack_types[] = {"short", "int", "long", "long_long",
					   "unsigned_short", "unsigned_int", "unsigned_long", "unsigned_long_long",
					   "int8", "int16", "int32", "int64",
					   "uint8", "uint16", "uint32", "uint64",
					   "fix_int8", "fix_int16", "fix_int32", "fix_int64",
					   "fix_uint8", "fix_uint16", "fix_uint32", "fix_uint64",
					   "float", "double",
					   "nil", "true", "false", "bool",
					   "array", "map", "list", "dict", "tclarray",
					   "raw", "raw_body", "string",
					   NULL};
	*tindex = -1;
	if (Tcl_GetIndexFromObj(ip, o, pack_types, "type", 0, tindex) != TCL_OK)
	    return TCL_ERROR;
	return TCL_OK;
    }

    static int pack_typed_data(Tcl_Interp* ip, MsgpackPackerClientData* pcd, int tindex, Tcl_Obj* d, Tcl_Obj* e, Tcl_Obj* f)
    {
	switch((enum PackerTypes)tindex){
	case PACKTYPE_SHORT:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected short", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_short(pcd->pk, i);
	    break;
	}
	case PACKTYPE_INT:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_int(pcd->pk, i);
	    break;
	}
	case PACKTYPE_LONG:
	{
	    long i = 0;
	    if (Tcl_GetLongFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected long", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_long(pcd->pk, i);
	    break;
	}
	case PACKTYPE_LONG_LONG:
	{
	    long long i = 0;
	    if (Tcl_GetWideIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected long long", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_long_long(pcd->pk, i);
	    break;
	}
	case PACKTYPE_USHORT:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected unsigned short", -1));
		return TCL_ERROR;
		}
	    msgpack_pack_unsigned_short(pcd->pk, i);
	    break;
	}
	case PACKTYPE_UINT:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected unsigned integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_unsigned_int(pcd->pk, i);
	    break;
	}
	case PACKTYPE_ULONG:
	{
	    long i = 0;
	    if (Tcl_GetLongFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected unsigned long", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_unsigned_long(pcd->pk, i);
	    break;
	}
	case PACKTYPE_ULONG_LONG:
	{
	    long long i = 0;
	    if (Tcl_GetWideIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected unsigned long long", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_unsigned_long_long(pcd->pk, i);
	    break;
	}
	case PACKTYPE_INT8:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_int8(pcd->pk, i);
	    break;
	}
	case PACKTYPE_INT16:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_int16(pcd->pk, i);
	    break;
	}
	case PACKTYPE_INT32:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_int32(pcd->pk, i);
	    break;
	}
	case PACKTYPE_INT64:
	{
	    long long i = 0;
	    if (Tcl_GetWideIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected long long", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_int64(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FIX_INT8:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_fix_int8(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FIX_INT16:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_fix_int16(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FIX_INT32:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_fix_int32(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FIX_INT64:
	{
	    long long i = 0;
	    if (Tcl_GetWideIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected long long", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_fix_int64(pcd->pk, i);
	    break;
	}
	case PACKTYPE_UINT8:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_uint8(pcd->pk, i);
	    break;
	}
	case PACKTYPE_UINT16:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_uint16(pcd->pk, i);
	    break;
	}
	case PACKTYPE_UINT32:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_uint32(pcd->pk, i);
	    break;
	}
	case PACKTYPE_UINT64:
	{
	    long long i = 0;
	    if (Tcl_GetWideIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected long long", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_uint64(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FIX_UINT8:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_fix_uint8(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FIX_UINT16:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_fix_uint16(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FIX_UINT32:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_fix_uint32(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FIX_UINT64:
	{
	    long long i = 0;
	    if (Tcl_GetWideIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected long long", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_fix_uint64(pcd->pk, i);
	    break;
	}
	case PACKTYPE_FLOAT:
	{
	    double i = 0;
	    if (Tcl_GetDoubleFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected float", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_float(pcd->pk, (float)i);
	    break;
	}
	case PACKTYPE_DOUBLE:
	{
	    double i = 0;
	    if (Tcl_GetDoubleFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected double", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_double(pcd->pk, i);
	    break;
	}
	case PACKTYPE_NIL:
	{
	    msgpack_pack_nil(pcd->pk);
	    break;
	}
	case PACKTYPE_TRUE:
	{
	    msgpack_pack_true(pcd->pk);
	    break;
	}
	case PACKTYPE_FALSE:
	{
	    msgpack_pack_false(pcd->pk);
	    break;
	}
	case PACKTYPE_BOOL:
	{
	    int i = 0;
	    if (Tcl_GetBooleanFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected boolean", -1));
		return TCL_ERROR;
	    }
	    if (i)
		msgpack_pack_true(pcd->pk);
	    else
		msgpack_pack_false(pcd->pk);
	    break;
	}
	case PACKTYPE_ARRAY:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer array size", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_array(pcd->pk, i);
	    break;
	}
	case PACKTYPE_MAP:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer map size", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_map(pcd->pk, i);
	    break;
	}
	case PACKTYPE_LIST:
	{
	    int etindex = -1;
	    int eobjc = 0;
	    Tcl_Obj** eobjv = 0;
	    if (get_pack_type(ip, d, &etindex) != TCL_OK)
		return TCL_ERROR;
	    if (Tcl_ListObjGetElements(ip, e, &eobjc, &eobjv) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected list", -1));
		return TCL_ERROR;
	    }
	    if (eobjc) {
		int i = 0;
		msgpack_pack_array(pcd->pk, eobjc);
		for(i = 0; i < eobjc; i++)
		    if (pack_typed_data(ip, pcd, etindex, eobjv[i], 0, 0) != TCL_OK)
			return TCL_ERROR;
	    }
	    break;
	}
	case PACKTYPE_DICT:
	{
	    int ktindex = -1;
	    int vtindex = -1;
	    int dsize = 0;
	    Tcl_DictSearch ds;
	    Tcl_Obj* keyp = 0;
	    Tcl_Obj* valp = 0;
	    int done = 0;
	    if (get_pack_type(ip, d, &ktindex) != TCL_OK)
		return TCL_ERROR;
	    if (get_pack_type(ip, e, &vtindex) != TCL_OK)
		return TCL_ERROR;
	    if (Tcl_DictObjSize(ip, f, &dsize) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected dict", -1));
		return TCL_ERROR;
	    }
	    if (dsize) {
		if (Tcl_DictObjFirst(ip, f, &ds, &keyp, &valp, &done) != TCL_OK) {
		    Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected dict", -1));
		    return TCL_ERROR;
		}
		msgpack_pack_map(pcd->pk, dsize);
		while(!done) {
		    if (pack_typed_data(ip, pcd, ktindex, keyp, 0, 0) != TCL_OK)
			return TCL_ERROR;
		    if (pack_typed_data(ip, pcd, vtindex, valp, 0, 0) != TCL_OK)
			return TCL_ERROR;
		    Tcl_DictObjNext(&ds, &keyp, &valp, &done);
		}
	    }
	    break;
	}
	case PACKTYPE_TCLARRAY:
	{
	    break;
	}
	case PACKTYPE_RAW:
	{
	    int i = 0;
	    if (Tcl_GetIntFromObj(ip, d, &i) != TCL_OK) {
		Tcl_SetObjResult(ip, Tcl_NewStringObj("Wrong value type, expected integer raw size", -1));
		return TCL_ERROR;
	    }
	    msgpack_pack_raw(pcd->pk, i);
	    break;
	}
	case PACKTYPE_RAW_BODY:
	{
	    int i = 0;
	    const char* p = Tcl_GetStringFromObj(d, &i);
	    msgpack_pack_raw_body(pcd->pk, p, i);
	    break;
	}
	case PACKTYPE_STRING:
	{
	    int i = 0;
	    const char* p = Tcl_GetStringFromObj(d, &i);
	    msgpack_pack_raw(pcd->pk, i);
	    msgpack_pack_raw_body(pcd->pk, p, i);
	    break;
	}
	}
	return TCL_OK;
    }

    int msgpack_packer_objcmd(ClientData cd, Tcl_Interp* ip, int objc, Tcl_Obj* const objv[]) {
	MsgpackPackerClientData* pcd = (MsgpackPackerClientData*)cd;
	static const char* methods[] = {"data", "destroy", "pack", "reset", NULL};
	enum PackerMethods {PACKER_DATA, PACKER_DESTROY, PACKER_PACK, PACKER_RESET};
	int index = -1;
	if (objc < 2) {
	    Tcl_WrongNumArgs(ip, 1, objv, "method ?argument ...?");
	    return TCL_ERROR;
	}
	if (Tcl_GetIndexFromObj(ip, objv[1], methods, "method", 0, &index) != TCL_OK)
            return TCL_ERROR;
	switch((enum PackerMethods)index){
	case PACKER_DATA:
	{
	    if (objc != 2) {
		Tcl_WrongNumArgs(ip, 2, objv, "");
		return TCL_ERROR;
	    }
	    Tcl_SetObjResult(ip, Tcl_NewByteArrayObj(pcd->sbuf->data, pcd->sbuf->size));
	    break;
	}
	case PACKER_DESTROY:
	{
	    if (objc != 2) {
		Tcl_WrongNumArgs(ip, 2, objv, "");
		return TCL_ERROR;
	    }
	    msgpack_packer_free(pcd->pk);
	    msgpack_sbuffer_free(pcd->sbuf);
	    Tcl_DecrRefCount(pcd->tcl_cmd);
	    Tcl_DeleteCommand(ip, Tcl_GetStringFromObj(objv[0], 0));
	    break;
	}
	case PACKER_PACK:
	{
	    int tindex = -1;
	    if (get_pack_type(ip, objv[2], &tindex) != TCL_OK)
		return TCL_ERROR;
	    switch((enum PackerTypes)tindex){
	    case PACKTYPE_SHORT:
	    case PACKTYPE_INT:
	    case PACKTYPE_LONG:
	    case PACKTYPE_LONG_LONG:
	    case PACKTYPE_USHORT:
	    case PACKTYPE_UINT:
	    case PACKTYPE_ULONG:
	    case PACKTYPE_ULONG_LONG:
	    case PACKTYPE_FLOAT:
	    case PACKTYPE_DOUBLE:
	    case PACKTYPE_BOOL:
	    case PACKTYPE_RAW_BODY:
	    case PACKTYPE_STRING:
	    {
		if (objc != 4) {
		    Tcl_WrongNumArgs(ip, 2, objv, "type data");
		    return TCL_ERROR;
		}
		break;
	    }
	    case PACKTYPE_ARRAY:
	    case PACKTYPE_MAP:
	    case PACKTYPE_RAW:
	    {
		if (objc != 4) {
		    Tcl_WrongNumArgs(ip, 2, objv, "type size");
		    return TCL_ERROR;
		}
		break;
	    }
	    case PACKTYPE_NIL:
	    case PACKTYPE_TRUE:
	    case PACKTYPE_FALSE:
	    {
		if (objc != 3) {
		    Tcl_WrongNumArgs(ip, 2, objv, "type");
		    return TCL_ERROR;
		}
		break;
	    }
	    case PACKTYPE_LIST:
	    {
		if (objc != 5) {
		    Tcl_WrongNumArgs(ip, 2, objv, "list element_type data");
		    return TCL_ERROR;
		}
		break;
	    }
	    case PACKTYPE_DICT:
	    {
		if (objc != 6) {
		    Tcl_WrongNumArgs(ip, 2, objv, "list key_type value_type data");
		    return TCL_ERROR;
		}
		break;
	    }
	    case PACKTYPE_TCLARRAY:
	    {
		if (objc != 6) {
		    Tcl_WrongNumArgs(ip, 2, objv, "list key_type value_type array_name");
		    return TCL_ERROR;
		}
		break;
	    }
	    }
	    if (pack_typed_data(ip, pcd, tindex, objv[3], objc>3?objv[4]:0, objc>4?objv[5]:0) != TCL_OK)
		return TCL_ERROR;
	    break;
	}
	case PACKER_RESET:
	{
	    if (objc != 2) {
		Tcl_WrongNumArgs(ip, 2, objv, "");
		return TCL_ERROR;
	    }
	    msgpack_packer_free(pcd->pk);
	    msgpack_sbuffer_free(pcd->sbuf);
	    pcd->sbuf = msgpack_sbuffer_new();
	    pcd->pk = msgpack_packer_new(pcd->sbuf, msgpack_sbuffer_write);
	    break;
	}
	}
	return TCL_OK;
    }

    static Tcl_Obj* msgpack_unpack_object(Tcl_Interp* ip, msgpack_object o)
    {
	Tcl_Obj* i = Tcl_NewListObj(0, 0);
	switch(o.type) {
	case MSGPACK_OBJECT_NIL:
	{
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("nil", -1));
	    break;
	}
	case MSGPACK_OBJECT_BOOLEAN:
	{
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("boolean", -1));
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewIntObj(o.via.boolean));
	    break;
	}
	case MSGPACK_OBJECT_POSITIVE_INTEGER:
	{
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("integer", -1));
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewWideIntObj(o.via.u64));
	    break;
	}
	case MSGPACK_OBJECT_NEGATIVE_INTEGER:
	{
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("integer", -1));
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewWideIntObj(o.via.i64));
	    break;
	}
	case MSGPACK_OBJECT_DOUBLE:
	{
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("double", -1));
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewDoubleObj(o.via.dec));
	    break;
	}
	case MSGPACK_OBJECT_RAW:
	{
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("raw", -1));
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj(o.via.raw.ptr, o.via.raw.size));
	    break;
	}
	case MSGPACK_OBJECT_ARRAY:
	{
	    int t = 0;
	    Tcl_Obj* a = Tcl_NewListObj(0, 0);
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("array", -1));
	    for(t = 0; t < o.via.array.size; t++)
		Tcl_ListObjAppendElement(ip, a, msgpack_unpack_object(ip, o.via.array.ptr[t]));
	    Tcl_ListObjAppendElement(ip, i, a);
	    break;
	}
	case MSGPACK_OBJECT_MAP:
	{
	    int t = 0;
	    Tcl_Obj* d = Tcl_NewDictObj();
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("map", -1));
	    for(t = 0; t < o.via.array.size; t++)
		Tcl_DictObjPut(ip, d,
			       msgpack_unpack_object(ip, o.via.map.ptr[t].key),
			       msgpack_unpack_object(ip, o.via.map.ptr[t].val));
	    Tcl_ListObjAppendElement(ip, i, d);
	    break;
	}
	default:
	{
	    Tcl_ListObjAppendElement(ip, i, Tcl_NewStringObj("unknown", -1));
	    break;
	}
	}
	return i;
    }
}

critcl::ccommand ::msgpack::packer {cd ip objc objv} {
    MsgpackPackerClientData* ccd = 0;
    Tcl_Obj* fqn = 0;
    if (objc == 2)
	fqn = unique_namespace_name(ip, objv[1], (MsgpackClientData*)cd);
    else if (objc == 1)
	fqn = unique_namespace_name(ip, 0, (MsgpackClientData*)cd);
    else {
	Tcl_WrongNumArgs(ip, 1, objv, "?name?");
	return TCL_ERROR;
    }
    if (!fqn)
	return TCL_ERROR;
    ccd = (MsgpackPackerClientData*)ckalloc(sizeof(MsgpackPackerClientData));
    ccd->tcl_cmd = fqn;
    ccd->sbuf = msgpack_sbuffer_new();
    ccd->pk = msgpack_packer_new(ccd->sbuf, msgpack_sbuffer_write);
    Tcl_CreateObjCommand(ip, Tcl_GetStringFromObj(fqn, 0), msgpack_packer_objcmd, (ClientData)ccd, msgpack_free_client_data);
    Tcl_SetObjResult(ip, fqn);
    return TCL_OK;
} -clientdata msgpackClientData

critcl::ccommand ::msgpack::unpack {cd ip objc objv} {
    Tcl_Obj* fqn = 0;
    msgpack_sbuffer* sbuf = 0;
    msgpack_unpacked msg;
    char* p = 0;
    int l = 0;
    Tcl_Obj* r = 0;
    size_t offset = 0;
    if (objc != 2) {
	Tcl_WrongNumArgs(ip, 1, objv, "data");
	return TCL_ERROR;
    }
    sbuf = msgpack_sbuffer_new();
    p = Tcl_GetByteArrayFromObj(objv[1], &l);
    msgpack_sbuffer_write(sbuf, p, l);
    msgpack_unpacked_init(&msg);
    r = Tcl_NewListObj(0, 0);
    while(msgpack_unpack_next(&msg, sbuf->data, sbuf->size, &offset))
	Tcl_ListObjAppendElement(ip, r, msgpack_unpack_object(ip, msg.data));
    msgpack_unpacked_destroy(&msg);
    msgpack_sbuffer_free(sbuf);
    Tcl_SetObjResult(ip, r);
    return TCL_OK;
} -clientdata msgpackClientData

critcl::ccommand ::msgpack::version {cd ip objc objv} {
    Tcl_SetObjResult(ip, Tcl_NewStringObj(msgpack_version(), -1));
    return TCL_OK;
} -clientdata msgpackClientData

critcl::cinit {
    msgpackClientData = (MsgpackClientData*)ckalloc(sizeof(MsgpackClientData));
    msgpackClientData->id = 0;
} {
    static MsgpackClientData* msgpackClientData = 0;
}

package provide msgpack 0.5.0

