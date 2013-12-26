module tvm.vm.objects;

import std.typetuple : TypeTuple, anySatisfy;
import std.bitmanip : bitfields;
import core.atomic;

import tvm.vm.utils;
import tvm.vm.allocator;
import tvm.vm.gc;

// NOTE Pointer to a compound object is the same as a pointer to its object header.
alias shared(TVMObject)* TVMPointer;

// A convenient wrapper for the simple, built-in types.
struct TVMValue {
    enum TYPE_BITS = 3;

    enum POINTER  = 0x0;
    enum FLOATING = 0x1;
    enum INTEGER  = 0x2;

    union {
        TVMPointer rawPtr;
        size_t rawValue;

        mixin(bitfields!(
            ubyte, "type", TYPE_BITS,
            size_t, "__value", 64 - TYPE_BITS));
    }

    this(TVMPointer ptr) {
        this(TVMValue.POINTER, cast(size_t) ptr);
    }

    this(double d) {
        this(TVMValue.FLOATING, cast(size_t) d);
    }

    this(long i) {
        this(TVMValue.INTEGER, cast(size_t) i);
    }

    this(ubyte type, size_t value) {
        this.value = value;
        this.type = type;
    }

    @property void value(T)(T newValue) {
        this.__value = cast(size_t) newValue;
    }

    @property T value(T)() const {
        return cast(T) __value;
    }

    @property T raw(T)() const {
        return cast(T) rawValue;
    }
}

auto value(T)(T value) {
    return TVMValue(value);
}

// TODO These should do the unwrapping:
//alias value!(long)       integer;
//alias value!(double)     floating;
//alias value!(TVMPointer) pointer;

bool isType(size_t type, T)(T v) {
    return v.type == type;
}

alias isType!(TVMValue.POINTER, TVMValue)  isPointer;
alias isType!(TVMValue.FLOATING, TVMValue) isReal;
alias isType!(TVMValue.INTEGER, TVMValue)  isInteger;

bool isNil(TVMValue v) {
    return isPointer(v) && (v.rawPtr is null);
}

bool isNil(TVMPointer ptr) {
    return ptr is null;
}

// An object header used in other, compound objects.
shared struct TVMObject {
    enum TYPE_BITS = 8;
    enum TYPE_MASK = (0x1 << TYPE_BITS) - 1;
    enum REF_COUNT_INCREMENT = (0x1 << TYPE_BITS);

    enum SYMBOL  = 0x0;
    enum PAIR    = 0x1;
    enum CLOSURE = 0x2;
    enum UPROC   = 0x3;

    private shared size_t value = 0;

    this(ubyte type) {
        this.type = type;
    }

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

alias isType!(TVMObject.SYMBOL, TVMPointer)  isSymbol;
alias isType!(TVMObject.PAIR, TVMPointer)    isPair;
alias isType!(TVMObject.CLOSURE, TVMPointer) isClosure;
alias isType!(TVMObject.UPROC, TVMPointer)   isMicroProc;

template isTVMObjectCompatible(T) {
    template isT(U) {
        static if(is(U == T)) enum isT = true;
        else                  enum isT = false;
    }

    static if(anySatisfy!(isT, TypeTuple!(TVMPointer, TVMSymbolPtr, TVMPairPtr,
                                          TVMClosurePtr, TVMMicroProcPtr, TVMContext)))
    {
        enum isTVMObjectCompatible = true;
    } else {
        enum isTVMObjectCompatible = false;
    }
}

// A TVMIR symbol.
alias shared(TVMSymbol)* TVMSymbolPtr;

shared struct TVMSymbol {
    TVMObject header = void;
    string str       = void; // NOTE This takes up two words.

    this(string str) {
        this.header = shared(TVMObject)(TVMObject.SYMBOL);
        this.str = str;
    }
}

auto symbol(Allocator)(Allocator a, string str) {
    auto ptr = alloc!TVMSymbol(a);
    *ptr = TVMSymbol(str);
    return use(ptr);
}

// A TVMIR ordered pair.
alias shared(TVMPair)* TVMPairPtr;

shared struct TVMPair {
    TVMObject header = void;
    TVMValue car     = void;
    TVMValue cdr     = void;

    this(TVMValue car, TVMValue cdr) {
        this.header = shared(TVMObject)(TVMObject.PAIR);
        this.car = cast(shared) car;
        this.cdr = cast(shared) cdr;
    }
}

auto pair(Allocator)(Allocator a, TVMValue car, TVMValue cdr) {
    auto ptr = alloc!TVMPair(a);
    *ptr = shared(TVMPair)(car, cdr);
    return use(ptr);
}

auto list(Allocator, Ts...)(Allocator a, Ts values) {
    static if(values.length == 0) return cast(TVMPointer) null;
    else                          return pair(a, values[0], value(list(a, values[1..$])));
}

// A TVMIR closure.
alias shared(TVMClosure)* TVMClosurePtr;

shared struct TVMClosure {
    TVMObject header = void;
    TVMValue code    = void;
    TVMValue env     = void;

    this(TVMValue code, TVMValue env) {
        this.header = shared(TVMObject)(TVMObject.CLOSURE);
        this.code = cast(shared) code;
        this.env = cast(shared) env;
    }
}

auto closure(Allocator)(Allocator a, TVMValue car, TVMValue cdr) {
    auto ptr = alloc!TVMClosure(a);
    *ptr = shared(TVMClosure)(car, cdr);
    return use(ptr);
}

// A TVMIR uProc context.
alias shared(TVMMicroProc)* TVMMicroProcPtr;
alias shared(TVMMicroProc)* TVMContext;

shared struct TVMMicroProc {
    enum PRIORITY_BITS = 6;
    enum PRIORITY_MASK = (0x1 << PRIORITY_BITS) - 1;

    enum SLEEP_BIT = PRIORITY_BITS;
    enum MAX_SLEEP_TIME = time_t.max;

    // Header:
    TVMObject header = void;

    // State registers:
    // NOTE These are always pointers, so the TVMValue wrapper is skipped here.
    // NOTE It is guaranteed that these pointers are accessed only by a single thread.
    TVMPointer code   = null;
    TVMPointer stack  = null;
    TVMPointer env    = null;
    TVMPointer vstack = null;

    // Allocator:
    TVMAllocator!GCAllocator* alloc = null;

    // MSGq:
    LockFreeQueue!TVMValue msgq = null;

    // Scheduler registers:
    mixin(bitfields!(
        ubyte, "priority", PRIORITY_BITS,
        bool, "asleep", 1,
        uint, "", 63 - PRIORITY_BITS));

    time_t runtime = void;

    this(size_t heapSize, size_t msgqSize, ubyte priority, time_t wakeTime) {
        this.header = shared(TVMObject)(TVMObject.UPROC);
        this.alloc = cast(shared) new TVMAllocator!GCAllocator(heapSize);
        this.msgq = cast(shared) new LockFreeQueue!TVMValue(msgqSize);
        this.priority = priority;
        this.wakeTime = wakeTime;
    }

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
