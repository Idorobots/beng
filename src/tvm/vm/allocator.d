module tvm.vm.allocator;

import core.memory;

import tvm.vm.objects;

shared struct GCAllocator {
    void[] allocate(size_t size) {
        auto p = GC.malloc(size);
        return p ? p[0..size] : null;
    }

    void deallocate(void[] mem) {
        GC.free(mem.ptr);
    }

    static shared GCAllocator it;
}

shared struct TVMAllocator(Allocator) {
    static if (__traits(compiles, Allocator.it)) alias Allocator.it parent;
    else Allocator parent;

    private TVMPointer freeList;

    this(size_t size) {
        auto mem = cast(TVMValue[]) parent.allocate(size * TVMValue.sizeof);

        // FIXME Check ranges, etc.
        for(uint i = 0; i < size-3; i += 3) {
            auto header = TVMObject(0);
            header.refCount = cast(size_t) &mem[i+3];

            // FIXME Setup types etc.
            auto p = TVMPair();
            mem[i..i+3] = *cast(TVMValue*) &p;
        }

        freeList = cast(TVMPointer) mem.ptr;
    }

    // FIXME Explicitly check for TVM types.
    T* allocate(T)() if(T.sizeof >= TVMValue.sizeof) {
        if(freeList !is null) {
            auto object = freeList;
            freeList = object.refCount;
            object.refCount = 1;
            return object;
        } else {
            auto mem = cast(TVMValue[]) parent.allocate(T.sizeof);
            mem[0] = TVMObject(0);
            mem[0].refCount = 1;
            return cast(T*) mem.ptr;
        }
    }

    void deallocate(T)(T* object) if(T.sizeof >= TVMValue.sizeof) {
        auto ptr = cast(TVMPointer) object;
        object.refCount = freeList;
        freeList = object;
    }
}
