module tvm.vm.bytecode;

import std.string : format;

import tvm.vm.objects;

alias opcode_t = ubyte;

struct TVMInstruction {
    enum WORD_BITS = 8 * TVMValue.sizeof;
    enum OPCODE_BITS = 8 * opcode_t.sizeof;
    enum OPCODE_SHIFT = WORD_BITS - OPCODE_BITS;
    enum OPCODE_MASK = ((0x1UL << OPCODE_BITS) - 1) << OPCODE_SHIFT;

    enum MAX_INTEGER_OPERAND = 0xffffffffffff8;
    enum MIN_INTEGER_OPERAND = -MAX_INTEGER_OPERAND;
    enum MAX_FLOATING_OPERAND = cast(double) float.max;
    enum MIN_FLOATING_OPERAND = -MAX_FLOATING_OPERAND;

    enum PUSH   = 0x0;
    enum TAKE   = 0x1;
    enum ENTER  = 0x2;
    enum PRIMOP = 0x3;
    enum COND   = 0x4;
    enum RETURN = 0x5;
    enum HALT   = 0x6;

    TVMValue arg;
    alias arg this;

    private TVMValue pack(TVMValue stuff) const {
        switch(stuff.type) {
            case TVMValue.POINTER:
                // NOTE On x86 2 MSB are always zero, so we're good to go.
                return stuff;

            case TVMValue.INTEGER:
                auto v = asInteger(stuff);
                assert((v <= MAX_INTEGER_OPERAND) || (v >= MIN_INTEGER_OPERAND),
                       "Bad instruction operand!");

                // NOTE Preparing for sign extension.
                stuff.rawValue &= ~OPCODE_MASK;
                return stuff;

            case TVMValue.FLOATING:
                // NOTE Preparing for rescaling later:
                auto d = asFloating(stuff);

                assert((d <= MAX_FLOATING_OPERAND) || (d >= MIN_FLOATING_OPERAND),
                       "Bad instruction operand!");

                float f = d;
                stuff.rawValue = *cast(size_t*) &f;
                stuff.type = TVMValue.FLOATING;

                return stuff;

            default:
                assert(0, format("Bad istruction operand type: %s.", stuff.type));
        }
    }

    private TVMValue unpack(TVMValue stuff) const {
        switch(stuff.type) {
            case TVMValue.POINTER:
                stuff.rawValue &= ~OPCODE_MASK;
                return stuff;

            case TVMValue.INTEGER:
                // NOTE Requires sign extension.
                auto extended = *cast(long*)&stuff.rawValue;
                extended = (extended << OPCODE_BITS) >> OPCODE_BITS;
                stuff.rawValue = *cast(size_t*) &extended;

                return stuff;

            case TVMValue.FLOATING:
                // NOTE Requires floating point rescale.
                stuff.floating = *cast(float*) &stuff.rawValue;

                return stuff;

            default:
                assert(0, format("Bad istruction operand type: %s.", stuff.type));
        }
    }

    this(opcode_t opcode, TVMValue arg) {
        this.arg = pack(arg);
        this.arg.rawValue &= ~OPCODE_MASK;
        this.arg.rawValue |= (cast(size_t) opcode) << OPCODE_SHIFT;
    }

    @property opcode_t opcode() const {
        return this.rawValue >> OPCODE_SHIFT;
    }

    @property TVMValue argument() const {
        return unpack(this.arg);
    }
}

TVMInstruction instruction(T)(opcode_t opcode, T argument) {
    return TVMInstruction(opcode, value(argument));
}

template makeInstr(opcode_t opcode) {
    auto makeInstr(T = long)(T argument = T.init) {
        return instruction!T(opcode, argument);
    }
}

alias push   = makeInstr!(TVMInstruction.PUSH);
alias take   = makeInstr!(TVMInstruction.TAKE);
alias enter  = makeInstr!(TVMInstruction.ENTER);
alias primop = makeInstr!(TVMInstruction.PRIMOP);
alias cond   = makeInstr!(TVMInstruction.COND);
alias ret    = makeInstr!(TVMInstruction.RETURN);
alias halt   = makeInstr!(TVMInstruction.HALT);

auto asInstruction(TVMValue v) {
    return cast(TVMInstruction) v;
}

unittest {
    import std.math;

    bool isOk(T)(T a, T b) {
        static if(is(T == TVMPointer)) {
            return a is b;
        }
        static if(is(T == double)) {
            return abs(a - b) < 0.00001 * abs(a + b);
        }
        static if(is(T == long)) {
            return a == b;
        }
    }

    TVMPointer ptr = cast(TVMPointer) 0x7ffff1234560;
    auto c = enter(ptr);
    assert(c.opcode == TVMInstruction.ENTER);
    assert(isOk(c.argument.ptr, ptr), format("Got %s", c.argument.ptr));

    auto d = enter(nil());
    assert(d.opcode == TVMInstruction.ENTER);
    assert(isOk(d.argument.ptr, nil()), format("Got %s", d.argument.ptr));

    auto e = enter(42.5);
    assert(e.opcode == TVMInstruction.ENTER);
    assert(isOk(e.argument.floating, 42.5), format("Got %s", e.argument.floating));

    auto f = enter(-42.5);
    assert(f.opcode == TVMInstruction.ENTER);
    assert(isOk(f.argument.floating, -42.5), format("Got %s", f.argument.floating));

    auto g = enter(TVMInstruction.MAX_FLOATING_OPERAND);
    assert(g.opcode == TVMInstruction.ENTER);
    assert(isOk(g.argument.floating, TVMInstruction.MAX_FLOATING_OPERAND),
           format("Got %s", g.argument.floating));

    auto h = enter(TVMInstruction.MIN_FLOATING_OPERAND);
    assert(h.opcode == TVMInstruction.ENTER);
    assert(isOk(h.argument.floating, TVMInstruction.MIN_FLOATING_OPERAND),
           format("Got %s", h.argument.floating));

    auto i = enter(23);
    assert(i.opcode == TVMInstruction.ENTER);
    assert(isOk(i.argument.integer, 23L), format("Got %s", i.argument.integer));

    auto j = enter(-23);
    assert(j.opcode == TVMInstruction.ENTER);
    assert(isOk(j.argument.integer, -23L), format("Got %s", j.argument.integer));

    auto k = enter(TVMInstruction.MAX_INTEGER_OPERAND);
    assert(k.opcode == TVMInstruction.ENTER);
    assert(isOk(k.argument.integer, TVMInstruction.MAX_INTEGER_OPERAND),
           format("Got %s", k.argument.integer));

    auto l = enter(TVMInstruction.MIN_INTEGER_OPERAND);
    assert(l.opcode == TVMInstruction.ENTER);
    assert(isOk(l.argument.integer, TVMInstruction.MIN_INTEGER_OPERAND),
           format("Got %s", l.argument.integer));
}