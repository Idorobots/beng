module tvm.vm.allocator;

import core.memory;

import tvm.vm.objects;

// D GC allocator:
shared struct GCAllocator {
    auto allocate(T)() {
        // NOTE GC.malloc is assured to return aligned block of GC'd memory.
        auto ptr = GC.malloc(T.sizeof);
        return cast(shared(T)*) ptr;
    }

    void deallocate(T)(T* ptr) {
        // NOTE GC.free could be used explicitly here
        // NOTE so memory is returned ASAP.
        // GC.free(cast(void*) ptr);
    }

    static shared GCAllocator it;
}

// TVM free-list allocator with D GC backup:
shared struct TVMAllocator(Allocator) {
    // FIXME Could use less ugly traits.
    static if (__traits(compiles, Allocator.it)) alias parent = Allocator.it;
    else                                         Allocator parent;

    private TVMPointer freeList = null;

    this(size_t size) {
        // FIXME Currently a bug prevents preallocation of the free list.
        preallocate(size);
    }

    void preallocate(size_t size) {
        TVMPointer last = freeList;

        while(size >= 3) {
            auto ptr = parent.allocate!TVMPair();

            *ptr = shared TVMPair(value(nil()), value(nil()));
            ptr.header.refCount = cast(size_t) last;

            // NOTE We need to remove the pointer from the D GC.
            GC.removeRoot(cast(void*) last);

            last = asObject(ptr);
            size -= 3;
        }

        freeList = last;
    }

    auto allocate(T)() {
        static if(T.sizeof == TVMPair.sizeof) {
            if(!isNil(this.freeList)) {
                auto object = this.freeList;
                this.freeList = cast(TVMPointer) object.refCount;

                // NOTE We need to return the pointer to the D GC.
                GC.addRoot(cast(void*) this.freeList);

                return cast(shared(T)*) object;
            } else {
                return parent.allocate!T();
            }
        } else {
            return parent.allocate!T();
        }
    }

    void deallocate(T)(T* object) {
        static if(T.sizeof == TVMPair.sizeof) {
            auto ptr = asObject(object);

            // NOTE We need to remove the pointer from the D GC.
            GC.removeRoot(cast(void*) this.freeList);

            ptr.refCount = cast(size_t) freeList;
            freeList = ptr;
        } else {
            parent.deallocate(object);
        }
    }
}