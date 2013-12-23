module tvm.vm.objects;

import std.bitmanip : bitfields;
import core.atomic;

import tvm.vm.utils;
import tvm.vm.allocator;

// NOTE Pointer to a compound object is the same as a pointer to its object header.
alias TVMPointer = shared(TVMObject)*;

// A convenient wrapper for the simple, built-in types.
struct TVMValue {
    enum TYPE_BITS = 3;

    union {
        TVMPointer rawPtr;
        size_t rawValue;

        mixin(bitfields!(
            ubyte, "type", TYPE_BITS,
            size_t, "__value", 64 - TYPE_BITS));
    }

    this(T)(ubyte type, T value) {
        this.value = value;
        this.type = type;
    }

    @property void value(T)(T newValue) {
        this.__value = cast(size_t) newValue;
    }

    @property T value(T)() {
        return cast(T) __value;
    }

    @property T raw(T)() const {
        return cast(T) rawValue;
    }
}

// An object header used in other, compound objects.
struct TVMObject {
    enum TYPE_BITS = 8;
    enum TYPE_MASK = (0x1 << TYPE_BITS) - 1;

    enum REF_COUNT_INCREMENT = (0x1 << TYPE_BITS);

    private shared size_t value;

    size_t incRefCount() {
        return atomicOp!"+="(this.value, REF_COUNT_INCREMENT) >> TYPE_BITS;
    }

    size_t decRefCount() {
        return atomicOp!"-="(this.value, REF_COUNT_INCREMENT) >> TYPE_BITS;
    }

    @property size_t refCount() const {
        return atomicLoad(this.value) >> TYPE_BITS;
    }

    @property void refCount(size_t newRefCount) {
        size_t currVal, t, rc;

        do {
            currVal = atomicLoad(this.value);
            t = currVal & TYPE_MASK;
            rc = (newRefCount << TYPE_BITS) | t;
        } while(!cas(&this.value, currVal, rc));
    }

    @property size_t type() const {
        return atomicLoad(this.value) & TYPE_MASK;
    }

    @property void type(size_t newType) {
        auto t = this.type;
        t |= TYPE_MASK;
        t &= (newType & TYPE_MASK);

        atomicStore(this.value, t);
    }
}

// A TVMIR symbol.
shared struct TVMSymbol {
    TVMObject header;
    string str; // NOTE This takes up two words.
}

// A TVMIR ordered pair.
shared struct TVMPair {
    TVMObject header;
    TVMValue car;
    TVMValue cdr;
}

// A TVMIR closure.
shared struct TVMClosure {
    TVMObject header;
    TVMValue code;
    TVMValue env;
}

// A TVMIR uProc context.
alias TVMContext = shared(TVMMicroProc)*;

shared struct TVMMicroProc {
    enum PRIORITY_BITS = 6;
    enum PRIORITY_MASK = (0x1 << PRIORITY_BITS) - 1;

    enum SLEEP_BIT = PRIORITY_BITS;
    enum MAX_SLEEP_TIME = time_t.max;

    // Header:
    TVMObject header;

    // State registers:
    // NOTE These are always pointers, so the TVMValue wrapper is skipped here.
    // NOTE It is guaranteed that these pointers are accessed only by a single thread.
    TVMPointer code;
    TVMPointer stack;
    TVMPointer env;
    TVMPointer vstack;

    // Allocator:
    TVMAllocator!GCAllocator* alloc;

    // MSGq:
    LockFreeQueue!TVMValue msgq;

    // Scheduler registers:
    mixin(bitfields!(
        ubyte, "priority", PRIORITY_BITS,
        bool, "asleep", 1,
        uint, "", 63 - PRIORITY_BITS));

    time_t runtime;

    @property void wakeTime(time_t wt) {
        asleep = true;
        runtime = wt;
    }

    @property time_t wakeTime() const {
        return runtime;
    }

    @property time_t vRunTime() const {
        return this.priority * runtime;
    }

    @property void vRunTime(time_t t) {
        asleep = false;
        runtime = t / this.priority;
    }
}
