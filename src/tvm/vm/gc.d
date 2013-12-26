module tvm.vm.gc;

import tvm.vm.objects;
import tvm.vm.allocator;

// The lazy ref-counting GC:
TVMPointer use(T)(T object) if(isTVMObjectCompatible!T) {
    // Every reference has to be use()'d and later free()'d.
    auto ptr = cast(TVMPointer) object;
    if(!isNil(ptr)) ptr.incRefCount;
    return ptr;
}

auto alloc(T, Allocator)(Allocator a) {
    auto object = a.allocate!T();

    // Lazily collect the references this object points to.
    collect(a, cast(TVMPointer) object);

    return object;
}

void collect(Allocator)(Allocator a, TVMPointer object) {
    foreach(ptr; refs(object)) {
        // Free every reference pointed to by this object.
        free(a, ptr);
    }
}

auto refs(TVMPointer object) {
    struct Range {
        TVMPointer ptr;
        size_t type;
        ubyte count;

        this(TVMPointer object) {
            this.type = object.type;
            this.count = 0;
            this.ptr = object;
        }

        bool empty() {
            switch(type) {
                case TVMObject.PAIR:
                    return (count > 2) ? true : false;
                case TVMObject.CLOSURE:
                    return (count > 2) ? true : false;
                case TVMObject.UPROC:
                    return (count > 4) ? true : false;
                default:
                    return true;
            }
        }

        TVMPointer front() {
            return cast(TVMPointer)(cast(size_t)ptr + count);
        }

        void popFront() {
            do {
                ++count;
            } while(shouldSkip());
        }

        private bool shouldSkip() {
            return isNil(this.front) || !isPointer(cast(TVMValue) this.front);
        }
    }

    // Returns an iterable range of references pointed to by the object.
    return Range(object);
}

void free(Allocator)(Allocator a, TVMPointer object) {
    // Deallocate the object if suitable.
    if(object.decRefCount == 0) {
        switch(object.type) {
            case TVMObject.SYMBOL:
                a.deallocate(cast(shared(TVMSymbol)*) object);
                break;
            case TVMObject.PAIR:
                a.deallocate(cast(shared(TVMPair)*) object);
                break;
            case TVMObject.CLOSURE:
                a.deallocate(cast(shared(TVMClosure)*) object);
                break;
            case TVMObject.UPROC:
                a.deallocate(cast(TVMContext) object);
                break;

            default:
                assert(0, "Bad object type!");
        }
    }
}