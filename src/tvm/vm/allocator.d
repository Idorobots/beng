module tvm.vm.allocator;

import core.memory;

import tvm.vm.objects;

// D GC allocator:
shared struct GCAllocator {
    auto allocate(T)() {
        auto ptr = GC.malloc(T.sizeof);
        return cast(shared(T)*) ptr;
    }

    void deallocate(T)(T* ptr) {
        GC.free(cast(void*) ptr);
    }

    static shared GCAllocator it;
}

// TVM free-list allocator with D GC backup:
shared struct TVMAllocator(Allocator) {
    static if (__traits(compiles, Allocator.it)) alias Allocator.it parent;
    else Allocator parent;

    private TVMPointer freeList = null;

    this(size_t size) {
        preallocate(size);
    }

    void preallocate(size_t size) {
        TVMPointer last = freeList;

        while(size >= 3) {
            auto ptr = parent.allocate!TVMPair();

            *ptr = shared(TVMPair)(TVMValue(cast(TVMPointer) null), TVMValue(cast(TVMPointer) null));
            ptr.header.refCount = cast(size_t) last;

            last = cast(TVMPointer) ptr;

            size -= 3;
        }

        freeList = last;
    }

    auto allocate(T)() {
        static if(T.sizeof == TVMPair.sizeof) {
            if(freeList !is null) {
                auto object = freeList;
                collect(object);
                freeList = cast(TVMPointer) object.refCount;

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
            auto ptr = cast(TVMPointer) object;
            object.refCount = freeList;
            freeList = object;
        } else {
            parent.deallocate(object);
        }
    }
}