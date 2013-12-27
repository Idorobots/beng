module tvm.vm.objects;

import std.typetuple : TypeTuple, anySatisfy;
import std.bitmanip : bitfields;
import core.atomic;

import tvm.vm.utils;
import tvm.vm.allocator;
import tvm.vm.gc;

// NOTE Pointer to a compound object is the same as a pointer to its object header.
alias TVMPointer = shared(TVMObject)*;

// A convenient wrapper for the simple, built-in types.
struct TVMValue {
    enum TYPE_BITS = 3;
    enum TYPE_MASK = (0x1 << TYPE_BITS) - 1;

    enum POINTER  = 0x0;
    enum FLOATING = 0x1;
    enum INTEGER  = 0x2;

    size_t rawValue;

    this(TVMPointer ptr) {
        // NOTE Since pointers are tagged with 0x0 we don't need to do anything.
        this.ptr = ptr;
    }

    this(double d) {
        this(TVMValue.FLOATING, (cast(size_t) d) << TYPE_BITS);
    }

    this(long i) {
        this(TVMValue.INTEGER, (cast(size_t) i) << TYPE_BITS);
    }

    this(ubyte type, size_t value) {
        this.rawValue = value;
        this.type = type;
    }

    @property ubyte type() const {
        return this.rawValue & TYPE_MASK;
    }

    @property void type(ubyte newType) {
        this.rawValue &= ~TYPE_MASK;
        this.rawValue |= (newType & TYPE_MASK);
    }

    @property T value(T)() const {
        return cast(T) (this.rawValue >> TYPE_BITS);
    }

    @property void value(T)(T newValue) {
        this.rawValue = (cast(size_t) newValue) << TYPE_BITS;
    }

    @property TVMPointer ptr() {
        // NOTE Since pointers are tagged with 0x0 we can use them directly.
        return cast(TVMPointer) rawValue;
    }

    @property void ptr(TVMPointer newPtr) {
        this.rawValue = cast(size_t) newPtr;
    }

    @property T raw(T)() const {
        return cast(T) rawValue;
    }

    @property void raw(T)(T newValue) {
        this.rawValue = cast(size_t) newValue;
    }
}

auto value(T)(T value) {
    return TVMValue(value);
}

bool isType(size_t type, T)(T v) {
    return v.type == type;
}

alias isPointer = isType!(TVMValue.POINTER, TVMValue);
alias isReal    = isType!(TVMValue.FLOATING, TVMValue);
alias isInteger = isType!(TVMValue.INTEGER, TVMValue);

bool isNil(TVMValue v) {
    // NOTE Requires explicit checking if the value is a pointer.
    return v.ptr is null;
}

bool isNil(TVMPointer ptr) {
    return ptr is null;
}

TVMPointer asPointer(TVMValue v) {
    return v.ptr;
}

double asReal(TVMValue v) {
    return v.value!double;
}

double asInteger(TVMValue v) {
    return v.value!long;
}

// An object header used in other, compound objects.
shared struct TVMObject {
    alias type_t = ubyte;
    enum TYPE_BITS = 8;
    enum TYPE_MASK = (0x1 << TYPE_BITS) - 1;
    enum REF_COUNT_INCREMENT = (0x1 << TYPE_BITS);

    enum SYMBOL  = 0x0;
    enum PAIR    = 0x1;
    enum CLOSURE = 0x2;
    enum UPROC   = 0x3;

    private size_t value = 0;

    this(type_t type) {
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

    @property type_t type() const {
        return atomicLoad(this.value) & TYPE_MASK;
    }

    @property void type(type_t newType) {
        size_t t = (newType & TYPE_MASK);
        atomicStore(this.value, t);
    }
}

alias isSymbol    = isType!(TVMObject.SYMBOL, TVMPointer);
alias isPair      = isType!(TVMObject.PAIR, TVMPointer);
alias isClosure   = isType!(TVMObject.CLOSURE, TVMPointer);
alias isMicroProc = isType!(TVMObject.UPROC, TVMPointer);

// A TVMIR symbol.
alias TVMSymbolPtr = shared(TVMSymbol)*;

shared struct TVMSymbol {
    TVMObject header = void;
    string str       = void; // NOTE This takes up two words.

    this(string str) {
        this.header = shared TVMObject(TVMObject.SYMBOL);
        this.str = str;
    }
}

auto symbol(Allocator)(Allocator a, string str) {
    auto ptr = alloc!TVMSymbol(a);
    *ptr = TVMSymbol(str);
    return use(ptr);
}

// A TVMIR ordered pair.
alias TVMPairPtr = shared(TVMPair)*;

shared struct TVMPair {
    TVMObject header = void;
    TVMValue car     = void;
    TVMValue cdr     = void;

    this(TVMValue car, TVMValue cdr) {
        this.header = shared TVMObject(TVMObject.PAIR);
        this.car = car;
        this.cdr = cdr;
    }
}

auto pair(Allocator)(Allocator a, TVMValue car, TVMValue cdr) {
    auto ptr = alloc!TVMPair(a);
    *ptr = shared TVMPair(car, cdr);
    return use(ptr);
}

auto list(Allocator, Ts...)(Allocator a, Ts values) {
    static if(values.length == 0) return cast(TVMPointer) null;
    else                          return pair(a, values[0], value(list(a, values[1..$])));
}

// A TVMIR closure.
alias TVMClosurePtr = shared(TVMClosure)*;

shared struct TVMClosure {
    TVMObject header = void;
    TVMValue code    = void;
    TVMValue env     = void;

    this(TVMValue code, TVMValue env) {
        this.header = shared TVMObject(TVMObject.CLOSURE);
        this.code = code;
        this.env = env;
    }
}

auto closure(Allocator)(Allocator a, TVMValue car, TVMValue cdr) {
    auto ptr = alloc!TVMClosure(a);
    *ptr = shared TVMClosure(car, cdr);
    return use(ptr);
}

// A TVMIR uProc context.
alias TVMMicroProcPtr = shared(TVMMicroProc)*;
alias TVMContext = shared(TVMMicroProc)*;

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
    // FIXME Create some custom methods for this.
    mixin(bitfields!(
        ubyte, "priority", PRIORITY_BITS,
        bool, "asleep", 1,
        uint, "", 63 - PRIORITY_BITS));

    time_t runtime = void;

    this(size_t heapSize, size_t msgqSize, ubyte priority, time_t wakeTime) {
        this.header = shared TVMObject(TVMObject.UPROC);
        this.alloc = new shared TVMAllocator!GCAllocator(heapSize);
        this.msgq = new shared LockFreeQueue!TVMValue(msgqSize);
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

template asType(T1) {
    T1 asType(T2)(T2 v) {
        return cast(T1) v;
    }
}

alias asSymbol    = asType!TVMSymbolPtr;
alias asPair      = asType!TVMPairPtr;
alias asClosure   = asType!TVMClosurePtr;
alias asMicroProc = asType!TVMMicroProcPtr;

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

TVMPointer asObject(T)(T object) if (isTVMObjectCompatible!T) {
    return cast(TVMPointer) object;
}
