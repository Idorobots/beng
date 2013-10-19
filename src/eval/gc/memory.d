module eval.gc.memory;

import std.bitmanip;
import eval.gc.gc;

struct SimpleValue {
    union {
        mixin(bitfields!(
            ubyte, "tag", 3,
            size_t, "value", 61
        ));

        mixin(bitfields!(
            size_t, "__operand", 48,
            ushort, "opcode", 16
        ));

        long asInteger;
        double asFloat;
        void* asPointer;
        size_t asBits;
    }

    @property SimpleValue operand() {
        return cast(SimpleValue) this.__operand;
    }

    @property void operand(SimpleValue that) {
        this.__operand = that.asBits;
    }
}

struct ObjectHeader {
    union {
        mixin(bitfields!(
            ubyte, "tag", 3,
            size_t, "", 61,
        ));

        mixin(bitfields!(
            size_t, "__hist", 48,
            ushort, "refCount", 16
        ));
    }

    @property void* history() {
        return cast(void*) (this.__hist - this.tag);
    }

    @property void history(void* that) {
        this.__hist = cast(size_t) that + this.tag;
    }
}

struct Cons {
    ObjectHeader header;
    SimpleValue car;
    SimpleValue cdr;

    this(ObjectHeader h, SimpleValue car, SimpleValue cdr) {
        this.header = h;
        this.car = car;
        this.cdr = cdr;
    }
}

SimpleValue mkPointer(void* ptr) {
    if(ptr !is null) {
        (cast(ObjectHeader*) ptr).mark();
    }

    SimpleValue v;
    v.asPointer = ptr;
    v.tag = 0b000;
    return v;
}

SimpleValue mkInteger(size_t integer) {
    SimpleValue v;
    v.tag = 0b010;
    v.value = integer;
    return v;
}

SimpleValue mkInteger(long integer) {
    return mkInteger(cast(size_t) integer);
}

SimpleValue mkFloat(double f) {
    SimpleValue v;
    v.asFloat = f;
    v.asBits += 0b001;
    return v;
}

SimpleValue mkSimple(double f) {
    return mkFloat(f);
}

SimpleValue mkSimple(void* ptr) {
    return mkPointer(ptr);
}

SimpleValue mkSimple(size_t integer) {
    return mkInteger(integer);
}

SimpleValue mkSimple(long integer) {
    return mkInteger(integer);
}

SimpleValue mkInstruction(ushort opcode, SimpleValue operand) {
    operand.opcode = opcode;
    return operand;
}

ObjectHeader mkHeader(ubyte tag, void* history) {
    ObjectHeader header;
    header.tag = tag;
    header.refCount = 1;
    header.history = history;
    return header;
}

Cons mkCons(SimpleValue car, SimpleValue cdr) {
    ObjectHeader header;
    header.refCount = 1;
    header.tag = 0b000;
    header.history = null;
    return Cons(header, car, cdr);
}
