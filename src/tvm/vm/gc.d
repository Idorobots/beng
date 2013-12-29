module tvm.vm.gc;

import tvm.vm.objects;
import tvm.vm.bytecode;
import tvm.vm.allocator;

// The lazy ref-counting GC:
auto alloc(T, Allocator)(Allocator a) {
    auto object = a.allocate!T();

    // Lazily collect the references this object points to.
    collect(a, asObject(object));

    return object;
}

TVMPointer use(T)(T object) {
    // Every reference has to be use()'d and later free()'d.
    auto ptr = asObject(object);
    if(!isNil(ptr)) ptr.incRefCount();
    return ptr;
}

TVMValue use(TVMValue object) {
    if(isPointer(object) && !isNil(object)) object.ptr.incRefCount();
    return object;
}

void collect(Allocator)(Allocator a, TVMPointer object) {
    // Collect objects pointed to by this objects references.
    switch(object.type) {
        case TVMObject.SYMBOL:
            // NOTE Nothing to free.
            goto default;

        case TVMObject.PAIR:
            free(a, asPair(object).car);
            free(a, asPair(object).cdr);
            break;

        case TVMObject.CLOSURE:
            free(a, asClosure(object).code);
            free(a, asClosure(object).env);
            break;

        case TVMObject.UPROC:
            free(a, asMicroProc(object).code);
            free(a, asMicroProc(object).env);
            free(a, asMicroProc(object).stack);
            free(a, asMicroProc(object).vstack);
            break;

        case TVMInstruction.INSTRUCTION:
            free(a, asInstruction(object).argument);
            break;

        default:
            return;
    }
}

void free(Allocator)(Allocator a, TVMValue value) {
    if(isPointer(value)) return free(a, value.ptr);
}

void free(Allocator)(Allocator a, TVMPointer obj) {
    // Deallocate the object if suitable.
    if(!isNil(obj) && (obj.decRefCount() == 0)) {
        switch(obj.type) {
            case TVMObject.SYMBOL:
                a.deallocate(asSymbol(obj));
                break;
            case TVMObject.PAIR:
                a.deallocate(asPair(obj));
                break;
            case TVMObject.CLOSURE:
                a.deallocate(asClosure(obj));
                break;
            case TVMObject.UPROC:
                a.deallocate(asMicroProc(obj));
                break;

            case TVMInstruction.INSTRUCTION:
                a.deallocate(asInstruction(obj));
                break;

            default:
                assert(0, "Bad object type!");
        }
    }
}