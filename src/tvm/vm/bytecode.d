module tvm.vm.bytecode;

import tvm.vm.objects;

alias ubyte opcode_t;

struct TVMInstruction {
    enum WORD_BITS = 8 * TVMValue.sizeof;
    enum OPCODE_BITS = 8 * opcode_t.sizeof;
    enum OPCODE_SHIFT = WORD_BITS - OPCODE_BITS;
    enum OPCODE_MASK = ((0x1UL << OPCODE_BITS) - 1) << OPCODE_SHIFT;

    enum PUSH   = 0x0;
    enum TAKE   = 0x1;
    enum ENTER  = 0x2;
    enum PRIMOP = 0x3;
    enum COND   = 0x4;
    enum RETURN = 0x5;
    enum HALT   = 0x6;

    TVMValue arg;
    alias arg this;

    this(opcode_t opcode, TVMValue arg) {
        this.arg = arg;

        // FIXME Should pack it somehow.
        assert((arg.rawValue & OPCODE_MASK) == 0, "Bad instruction argument!");
        this.arg.rawValue += (cast(size_t) opcode) << OPCODE_SHIFT;
    }

    @property opcode_t opcode() const {
        auto rawValue = argument.rawValue;
        return rawValue >> OPCODE_SHIFT;
    }

    @property TVMValue argument() const {
        TVMValue a = this.arg;
        a.rawValue &= ~OPCODE_MASK;
        return a;
    }
}

TVMInstruction instruction(T)(opcode_t opcode, T argument) {
    return TVMInstruction(opcode, value(argument));
}

opcode_t opcode(TVMInstruction instruction) {
    return instruction.opcode;
}

TVMValue argument(TVMInstruction instruction) {
    return instruction.argument;
}

template makeInstr(opcode_t opcode) {
    auto makeInstr(T)(T argument) {
        return instruction!T(opcode, argument);
    }
}

alias makeInstr!(TVMInstruction.PUSH)   push;
alias makeInstr!(TVMInstruction.TAKE)   take;
alias makeInstr!(TVMInstruction.ENTER)  enter;
alias makeInstr!(TVMInstruction.PRIMOP) primop;
alias makeInstr!(TVMInstruction.COND)   cond;
alias makeInstr!(TVMInstruction.RETURN) ret;
alias makeInstr!(TVMInstruction.HALT)   halt;
