/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.expr.vm.vm;
import inochi2d.expr.vm.value;
import inochi2d.expr.vm.opcodes;
import inochi2d.expr.vm.stack;
import numem.all;
import std.string;


/**
    Local execution state
*/
struct InVmState {
@nogc:

    // Value Stack
    InVmValueStack stack;

    // Call stack
    InVmCallStack callStack;

    /// Bytecode being executed
    ubyte[] bc;

    /// Program counter
    uint pc;

    /// Current operation flag
    ubyte flags;

    /// Get if the previous CMP flag was set to Equal
    bool flagEq() {
        return (flags & InVmFlag.eq) != 0;
    }

    /// Get if the previous CMP flag was set to Below
    bool flagBelow() {
        return (flags & InVmFlag.below) != 0;
    }

    /// Get if the previous CMP flag was set to Above
    bool flagAbove() {
        return flags == 0;
    }
}

enum InVmFlag : ubyte {
    /// Equal flag (zero flag)
    eq          = 0b0000_0001,

    /// Below flag (carry flag)
    below       = 0b0000_0010,

    /// Invalid operation flag.
    invalidOp   = 0b0001_0000,
}

/**
    A execution environment
*/
abstract
class InVmExecutor {
@nogc:
private:
    InVmState state;

    void _vmcmp(T)(T lhs, T rhs) {
        state.flags = 0;

        if (lhs == rhs) state.flags |= InVmFlag.eq;
        if (lhs < rhs)  state.flags |= InVmFlag.below;
    }

    struct _vmGlobalState {
        map!(nstring, InVmValue) globals;
    }

protected:

    /**
        Gets the local execution state
    */
    final
    InVmState getState() {
        return state;
    }

    /**
        Gets the global execution state
    */
    abstract _vmGlobalState* getGlobalState();

    /**
        Jumps to the specified address.
    */
    final
    void jump(size_t offset) {
        if (offset >= state.pc) return;
        state.pc = cast(uint)offset;
    }

    /**
        Runs a single instruction
    */
    final
    bool runOne() {
        import core.stdc.stdio : printf;
        InVmOpCode opcode = cast(InVmOpCode)state.bc[state.pc++];
        
        switch(opcode) {
            default:
                return false;

            case InVmOpCode.NOP:
                return true;
            
            case InVmOpCode.ADD:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(InVmValue(lhs.number + rhs.number));
                }
                return false;
            
            case InVmOpCode.SUB:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(InVmValue(lhs.number - rhs.number));
                }
                return false;
            
            case InVmOpCode.MUL:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(InVmValue(lhs.number * rhs.number));
                }
                return false;
            
            case InVmOpCode.DIV:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(InVmValue(lhs.number / rhs.number));
                }
                return false;
            
            case InVmOpCode.MOD:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    import inmath.math : fmodf;
                    state.stack.pop(2);
                    state.stack.push(InVmValue(fmodf(lhs.number, rhs.number)));
                }
                return false;
            
            case InVmOpCode.NEG:
                InVmValue* lhsp = state.stack.peek(0);
                if (!lhsp) 
                    return false;
                
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric) {
                    state.stack.pop(1);
                    state.stack.push(InVmValue(-lhs.number));
                }
                return false;

            case InVmOpCode.PUSH_n:
                ubyte[4] val = state.bc[state.pc..state.pc+4];
                float f32 = fromEndian!float(val, Endianess.littleEndian);
                state.stack.push(InVmValue(f32));
                state.pc += 4;
                return true;

            case InVmOpCode.PUSH_s:
                ubyte[4] val = state.bc[state.pc..state.pc+4];
                state.pc += 4;

                uint length = fromEndian!uint(val, Endianess.littleEndian);
                
                // Invalid string.
                if (state.pc+length >= state.bc.length)
                    return false;

                nstring nstr = cast(string)state.bc[state.pc..state.pc+length];
                state.stack.push(InVmValue(nstr));

                state.pc += length;
                return true;

            case InVmOpCode.POP:
                ptrdiff_t offset = state.bc[state.pc++];
                ptrdiff_t count = state.bc[state.pc++];
                state.stack.pop(offset, count);
                return true;

            case InVmOpCode.PEEK:
                ptrdiff_t offset = state.bc[state.pc++];
                state.stack.push(*state.stack.peek(offset));
                return true;

            case InVmOpCode.CMP:
                state.flags = InVmFlag.invalidOp;

                InVmValue* rhs = state.stack.peek(0);
                InVmValue* lhs = state.stack.peek(1);

                if (lhs.isNumeric && rhs.isNumeric) {
                    _vmcmp(lhs.number, rhs.number);
                }
                return false;

            case InVmOpCode.JMP:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                this.jump(addr);
                return true;

            case InVmOpCode.JEQ:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagEq())
                    this.jump(addr);
                return true;

            case InVmOpCode.JNQ:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (!state.flagEq())
                    this.jump(addr);
                return true;

            case InVmOpCode.JL:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagBelow())
                    this.jump(addr);
                return true;

            case InVmOpCode.JLE:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagBelow() || state.flagEq())
                    this.jump(addr);
                return true;

            case InVmOpCode.JG:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagAbove())
                    this.jump(addr);
                return true;

            case InVmOpCode.JGE:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagAbove() || state.flagEq())
                    this.jump(addr);
                return true;

            case InVmOpCode.JSR:

                // Get information
                InVmValue* func = state.stack.pop();
                if (!func || !func.isCallable()) return false;

                if (func.isNativeFunction()) {

                    func.func(state.stack);

                } else {

                    // Store return pointer
                    InVmFrame frame;
                    frame.prog = state.bc;
                    frame.pc = state.pc;

                    state.callStack.push(frame);
                    this.state.pc = 0;
                    this.state.bc = func.bytecode[];
                }
                return true;

            case InVmOpCode.RET:
                ptrdiff_t stackDepth = cast(ptrdiff_t)state.callStack.getDepth();
                
                // CASE: Return to host
                if (stackDepth-1 < 0) {
                    return false;
                }

                // Return to caller
                InVmFrame* frame = state.callStack.pop();

                // No frame?
                if (!frame) return false;

                // Restore previous frame
                this.state.pc = frame.pc;
                this.state.bc = frame.prog;
                return true;

            case InVmOpCode.SETG:
                InVmValue* name = state.stack.pop();
                InVmValue* item = state.stack.pop();

                if (name && item && name.getType() == InVmValueType.str) {
                    state.stack.pop(2);

                    this.getGlobalState().globals[name.str] = *item;
                    return true;
                }
                return false;
                
            case InVmOpCode.GETG:
                InVmValue* name = state.stack.pop();
                if (name && name.getType() == InVmValueType.str) {

                    if (name.str in this.getGlobalState().globals) {
                        state.stack.push(this.getGlobalState().globals[name.str]);
                        return true;
                    }
                }
                return false;


        }
    }

    /**
        Runs code

        Returns the depth of the stack on completion.
    */
    size_t run() {
        while(this.runOne()) { }
        return state.stack.getDepth();
    }

    this() {
        state.stack = nogc_new!InVmValueStack();
        state.callStack = nogc_new!InVmCallStack();
    }

public:

    ~this() {
        nogc_delete(state.stack);
        nogc_delete(state.callStack);
    }

    /**
        Gets global value
    */
    InVmValue* getGlobal(nstring name) {
        if (name in getGlobalState().globals) {
            return &getGlobalState().globals[name];
        }
        return null;
    }

    /**
        Sets global value
    */
    void setGlobal(nstring name, InVmValue value) {
        getGlobalState().globals[name] = value;
    }

    /**
        Pushes a float to the stack
    */
    final
    void push(float f32) {
        state.stack.push(InVmValue(f32));
    }

    /**
        Pushes a string to the stack
    */
    final
    void push(nstring str) {
        state.stack.push(InVmValue(str));
    }
    
    /**
        Pushes a ExprValue to the stack
    */
    final
    void push(InVmValue val) {
        state.stack.push(val);
    }

    /**
        Pops a ExprValue from the stack
    */
    final
    InVmValue peek(ptrdiff_t offset) {
        InVmValue v;

        auto p = state.stack.peek(offset);
        if (p) {
            v = *p;
        }

        return v;
    }

    /**
        Pops a ExprValue from the stack
    */
    final
    InVmValue pop() {
        InVmValue v;

        auto p = state.stack.peek(0);
        if (p) {
            v = *state.stack.pop();
        }

        return v;
    }

    /**
        Gets depth of stack
    */
    final
    size_t getStackDepth() {
        return state.stack.getDepth();
    }
}

class InVmVM : InVmExecutor {
@nogc:
private:
    shared_ptr!_vmGlobalState globalState;

protected:
    override
    _vmGlobalState* getGlobalState() {
        return globalState.get();
    }

public:
    this() {
        this.globalState = shared_new!_vmGlobalState;
    }

    /**
        Executes code in global scope.

        Returns size of stack after operation.
    */
    int execute(ubyte[] bytecode) {
        state.bc = bytecode;
        state.pc = 0;

        // Run and get return values
        size_t rval = run();

        // Reset code and program counter.
        state.pc = 0;
        state.bc = null;
        return cast(int)rval;
    }

    /**
        Calls a global function

        Returns return value count.
        Returns -1 on error.
    */
    int call(nstring gfunc) {
        InVmValue* v = this.getGlobal(gfunc);
        if (v && v.isCallable()) {
            if (v.isNativeFunction()) {
                return v.func(state.stack);
            } else {
                size_t rval = execute(v.bytecode[]);
                return cast(int)rval;
            }
        }
        return -1;
    }
}


//
//      UNIT TESTS
//

import inochi2d.expr.vm.builder : InVmBytecodeBuilder;

@("VM: NATIVE CALL")
unittest {
    import inmath.math : sin;

    // Sin function
    static int mySinFunc(ref InVmValueStack stack) @nogc {
        InVmValue* v = stack.pop();
        if (v && v.isNumeric) {
            stack.push(InVmValue(sin(v.number)));
            return 1;
        }
        return 0;
    }

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("sin"), InVmValue(&mySinFunc));

    vm.push(1.0);
    int retValCount = vm.call(nstring("sin"));
    
    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == sin(1.0f));
}

@("VM: ADD")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildADD();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("add"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(32.0);
    int retValCount = vm.call(nstring("add"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 64.0f);
}

@("VM: SUB")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildSUB();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("sub"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(32.0);
    int retValCount = vm.call(nstring("sub"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 0.0f);
}

@("VM: DIV")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildDIV();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("div"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(2.0);
    int retValCount = vm.call(nstring("div"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 16.0f);
}

@("VM: MUL")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildMUL();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("mul"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(2.0);
    int retValCount = vm.call(nstring("mul"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 64.0f);
}

@("VM: MOD")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildMOD();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("mod"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(16.0);
    int retValCount = vm.call(nstring("mod"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 0.0f);
}

@("VM: JSR NATIVE")
unittest {
    import std.stdio : writeln;
    import inmath.math : sin;

    // Sin function
    static int mySinFunc(ref InVmValueStack stack) @nogc {
        InVmValue* v = stack.pop();
        if (v && v.isNumeric) {
            stack.push(InVmValue(sin(v.number)));
            return 1;
        }
        return 0;
    }
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    
    // Parameters
    builder.buildPUSH(1.0);
    
    // Function get
    builder.buildPUSH("sin");
    builder.buildGETG();

    // Jump
    builder.buildJSR();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("sin"), InVmValue(&mySinFunc));
    vm.setGlobal(nstring("bcfunc"), InVmValue(builder.finalize()));

    int retValCount = vm.call(nstring("bcfunc"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == sin(1.0f));
}