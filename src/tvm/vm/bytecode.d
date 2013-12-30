module tvm.vm.bytecode;

import std.string : format;

import tvm.vm.objects;
import tvm.vm.gc;

alias opcode_t = ubyte;

// TVM instructions.
// FIXME This is a half-assed reimplementation of a buggy, TVMValue-packed instruction encoding.
alias TVMInstructionPtr = shared(TVMInstruction)*;

shared struct TVMInstruction {
    enum INSTRUCTION = TVMObject.LAST_TYPE + 1;

    enum ADDR_VAL  = 0x0;
    enum ADDR_ARG  = 0x1;
    enum ADDR_CODE = 0x2;

    enum PUSH   = 0x0;
    enum NEXT   = 0x1;
    enum TAKE   = 0x2;
    enum ENTER  = 0x3;
    enum PRIMOP = 0x4;
    enum COND   = 0x5;
    enum SPAWN  = 0x6;
    enum HALT   = 0x7;

    TVMObject header;
    uint opcode_, addressing_;
    TVMValue argument;

    this(opcode_t opcode, opcode_t addressing, TVMValue arg) {
        this.header = shared TVMObject(TVMInstruction.INSTRUCTION);
        this.opcode_ = opcode;
        this.addressing_ = addressing;
        this.argument = arg;
    }

    @property opcode_t opcode() const {
        return cast(opcode_t) this.opcode_;
    }

    @property opcode_t addressing() const {
        return cast(opcode_t) this.addressing_;
    }
}

auto instruction(T, Allocator)(Allocator a, opcode_t opcode, opcode_t addressing, T arg) {
    TVMValue argument = void;

    static if(is(T == TVMValue)) argument = arg;
    else                         argument = value(arg);

    auto ptr = alloc!TVMInstruction(a);
    *ptr = shared TVMInstruction(opcode, addressing, argument);
    return use(ptr);
}

template makeInstr(opcode_t opcode) {
    auto makeInstr(T = long, Allocator)(opcode_t addressing, Allocator a, T argument = T.init) {
        return instruction!(T, Allocator)(a, opcode, addressing, argument);
    }
}

template makeSimpleInstr(opcode_t opcode) {
    auto makeSimpleInstr(T = long, Allocator)(Allocator a, T argument = T.init) {
        return instruction!(T, Allocator)(a, opcode, TVMInstruction.ADDR_VAL, argument);
    }
}

auto addr(opcode_t addressing)() {
    return addressing;
}

alias val = addr!(TVMInstruction.ADDR_VAL);
alias arg = addr!(TVMInstruction.ADDR_ARG);
alias code = addr!(TVMInstruction.ADDR_CODE);

alias push   = makeSimpleInstr!(TVMInstruction.PUSH);
alias next   = makeInstr!(TVMInstruction.NEXT);
alias take   = makeSimpleInstr!(TVMInstruction.TAKE);
alias enter  = makeInstr!(TVMInstruction.ENTER);
alias primop = makeSimpleInstr!(TVMInstruction.PRIMOP);
alias cond   = makeSimpleInstr!(TVMInstruction.COND);
alias spawn  = makeSimpleInstr!(TVMInstruction.SPAWN);
alias halt   = makeSimpleInstr!(TVMInstruction.HALT);

bool isInstruction(TVMPointer obj) {
    return !isNil(obj) && (obj.type == TVMInstruction.INSTRUCTION);
}

alias asInstruction = asType!TVMInstructionPtr;
