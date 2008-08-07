//===-- IA64AsmPrinter.cpp - Print out IA64 LLVM as assembly --------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file contains a printer that converts from our internal representation
// of machine-dependent LLVM code to assembly accepted by the GNU binutils 'gas'
// assembler. The Intel 'ias' and HP-UX 'as' assemblers *may* choke on this
// output, but if so that's a bug I'd like to hear about: please file a bug
// report in bugzilla. FYI, the not too bad 'ias' assembler is bundled with
// the Intel C/C++ compiler for Itanium Linux.
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "asm-printer"
#include "IA64.h"
#include "IA64TargetMachine.h"
#include "llvm/Module.h"
#include "llvm/Type.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/Target/TargetAsmInfo.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Support/Mangler.h"
#include "llvm/ADT/Statistic.h"
using namespace llvm;

STATISTIC(EmittedInsts, "Number of machine instrs printed");

namespace {
  struct IA64AsmPrinter : public AsmPrinter {
    std::set<std::string> ExternalFunctionNames, ExternalObjectNames;

    IA64AsmPrinter(std::ostream &O, TargetMachine &TM, const TargetAsmInfo *T)
      : AsmPrinter(O, TM, T) {
    }

    virtual const char *getPassName() const {
      return "IA64 Assembly Printer";
    }

    /// printInstruction - This method is automatically generated by tablegen
    /// from the instruction set description.  This method returns true if the
    /// machine instruction was sufficiently described to print it, otherwise it
    /// returns false.
    bool printInstruction(const MachineInstr *MI);

    // This method is used by the tablegen'erated instruction printer.
    void printOperand(const MachineInstr *MI, unsigned OpNo){
      const MachineOperand &MO = MI->getOperand(OpNo);
      if (MO.getType() == MachineOperand::MO_Register) {
        assert(TargetRegisterInfo::isPhysicalRegister(MO.getReg()) &&
               "Not physref??");
        //XXX Bug Workaround: See note in Printer::doInitialization about %.
        O << TM.getRegisterInfo()->get(MO.getReg()).AsmName;
      } else {
        printOp(MO);
      }
    }

    void printS8ImmOperand(const MachineInstr *MI, unsigned OpNo) {
      int val=(unsigned int)MI->getOperand(OpNo).getImm();
      if(val>=128) val=val-256; // if negative, flip sign
      O << val;
    }
    void printS14ImmOperand(const MachineInstr *MI, unsigned OpNo) {
      int val=(unsigned int)MI->getOperand(OpNo).getImm();
      if(val>=8192) val=val-16384; // if negative, flip sign
      O << val;
    }
    void printS22ImmOperand(const MachineInstr *MI, unsigned OpNo) {
      int val=(unsigned int)MI->getOperand(OpNo).getImm();
      if(val>=2097152) val=val-4194304; // if negative, flip sign
      O << val;
    }
    void printU64ImmOperand(const MachineInstr *MI, unsigned OpNo) {
      O << (uint64_t)MI->getOperand(OpNo).getImm();
    }
    void printS64ImmOperand(const MachineInstr *MI, unsigned OpNo) {
// XXX : nasty hack to avoid GPREL22 "relocation truncated to fit" linker
// errors - instead of add rX = @gprel(CPI<whatever>), r1;; we now
// emit movl rX = @gprel(CPI<whatever);;
//      add  rX = rX, r1;
// this gives us 64 bits instead of 22 (for the add long imm) to play
// with, which shuts up the linker. The problem is that the constant
// pool entries aren't immediates at this stage, so we check here.
// If it's an immediate, print it the old fashioned way. If it's
// not, we print it as a constant pool index.
      if(MI->getOperand(OpNo).isImmediate()) {
        O << (int64_t)MI->getOperand(OpNo).getImm();
      } else { // this is a constant pool reference: FIXME: assert this
        printOp(MI->getOperand(OpNo));
      }
    }

    void printGlobalOperand(const MachineInstr *MI, unsigned OpNo) {
      printOp(MI->getOperand(OpNo), false); // this is NOT a br.call instruction
    }

    void printCallOperand(const MachineInstr *MI, unsigned OpNo) {
      printOp(MI->getOperand(OpNo), true); // this is a br.call instruction
    }

    std::string getSectionForFunction(const Function &F) const;

    void printMachineInstruction(const MachineInstr *MI);
    void printOp(const MachineOperand &MO, bool isBRCALLinsn= false);
    void printModuleLevelGV(const GlobalVariable* GVar);
    bool runOnMachineFunction(MachineFunction &F);
    bool doInitialization(Module &M);
    bool doFinalization(Module &M);
  };
} // end of anonymous namespace


// Include the auto-generated portion of the assembly writer.
#include "IA64GenAsmWriter.inc"


// Substitute old hook with new one temporary
std::string IA64AsmPrinter::getSectionForFunction(const Function &F) const {
  return TAI->SectionForGlobal(&F);
}

/// runOnMachineFunction - This uses the printMachineInstruction()
/// method to print assembly for each instruction.
///
bool IA64AsmPrinter::runOnMachineFunction(MachineFunction &MF) {
  SetupMachineFunction(MF);
  O << "\n\n";

  // Print out constants referenced by the function
  EmitConstantPool(MF.getConstantPool());

  const Function *F = MF.getFunction();
  SwitchToTextSection(getSectionForFunction(*F).c_str(), F);

  // Print out labels for the function.
  EmitAlignment(5);
  O << "\t.global\t" << CurrentFnName << "\n";
  O << "\t.type\t" << CurrentFnName << ", @function\n";
  O << CurrentFnName << ":\n";

  // Print out code for the function.
  for (MachineFunction::const_iterator I = MF.begin(), E = MF.end();
       I != E; ++I) {
    // Print a label for the basic block if there are any predecessors.
    if (!I->pred_empty()) {
      printBasicBlockLabel(I, true, true);
      O << '\n';
    }
    for (MachineBasicBlock::const_iterator II = I->begin(), E = I->end();
         II != E; ++II) {
      // Print the assembly for the instruction.
      printMachineInstruction(II);
    }
  }

  // We didn't modify anything.
  return false;
}

void IA64AsmPrinter::printOp(const MachineOperand &MO,
                             bool isBRCALLinsn /* = false */) {
  const TargetRegisterInfo &RI = *TM.getRegisterInfo();
  switch (MO.getType()) {
  case MachineOperand::MO_Register:
    O << RI.get(MO.getReg()).AsmName;
    return;

  case MachineOperand::MO_Immediate:
    O << MO.getImm();
    return;
  case MachineOperand::MO_MachineBasicBlock:
    printBasicBlockLabel(MO.getMBB());
    return;
  case MachineOperand::MO_ConstantPoolIndex: {
    O << "@gprel(" << TAI->getPrivateGlobalPrefix()
      << "CPI" << getFunctionNumber() << "_" << MO.getIndex() << ")";
    return;
  }

  case MachineOperand::MO_GlobalAddress: {

    // functions need @ltoff(@fptr(fn_name)) form
    GlobalValue *GV = MO.getGlobal();
    Function *F = dyn_cast<Function>(GV);

    bool Needfptr=false; // if we're computing an address @ltoff(X), do
                         // we need to decorate it so it becomes
                         // @ltoff(@fptr(X)) ?
    if (F && !isBRCALLinsn /*&& F->isDeclaration()*/)
      Needfptr=true;

    // if this is the target of a call instruction, we should define
    // the function somewhere (GNU gas has no problem without this, but
    // Intel ias rightly complains of an 'undefined symbol')

    if (F /*&& isBRCALLinsn*/ && F->isDeclaration())
      ExternalFunctionNames.insert(Mang->getValueName(MO.getGlobal()));
    else
      if (GV->isDeclaration()) // e.g. stuff like 'stdin'
        ExternalObjectNames.insert(Mang->getValueName(MO.getGlobal()));

    if (!isBRCALLinsn)
      O << "@ltoff(";
    if (Needfptr)
      O << "@fptr(";
    O << Mang->getValueName(MO.getGlobal());

    if (Needfptr && !isBRCALLinsn)
      O << "#))"; // close both fptr( and ltoff(
    else {
      if (Needfptr)
        O << "#)"; // close only fptr(
      if (!isBRCALLinsn)
        O << "#)"; // close only ltoff(
    }

    int Offset = MO.getOffset();
    if (Offset > 0)
      O << " + " << Offset;
    else if (Offset < 0)
      O << " - " << -Offset;
    return;
  }
  case MachineOperand::MO_ExternalSymbol:
    O << MO.getSymbolName();
    ExternalFunctionNames.insert(MO.getSymbolName());
    return;
  default:
    O << "<AsmPrinter: unknown operand type: " << MO.getType() << " >"; return;
  }
}

/// printMachineInstruction -- Print out a single IA64 LLVM instruction
/// MI to the current output stream.
///
void IA64AsmPrinter::printMachineInstruction(const MachineInstr *MI) {
  ++EmittedInsts;

  // Call the autogenerated instruction printer routines.
  printInstruction(MI);
}

bool IA64AsmPrinter::doInitialization(Module &M) {
  bool Result = AsmPrinter::doInitialization(M);

  O << "\n.ident \"LLVM-ia64\"\n\n"
    << "\t.psr    lsb\n"  // should be "msb" on HP-UX, for starters
    << "\t.radix  C\n"
    << "\t.psr    abi64\n"; // we only support 64 bits for now
  return Result;
}

void IA64AsmPrinter::printModuleLevelGV(const GlobalVariable* GVar) {
  const TargetData *TD = TM.getTargetData();

  if (!GVar->hasInitializer())
    return; // External global require no code

  // Check to see if this is a special global used by LLVM, if so, emit it.
  if (EmitSpecialLLVMGlobal(GVar))
    return;

  O << "\n\n";
  std::string SectionName = TAI->SectionForGlobal(GVar);
  std::string name = Mang->getValueName(GVar);
  Constant *C = GVar->getInitializer();
  unsigned Size = TD->getABITypeSize(C->getType());
  unsigned Align = TD->getPreferredAlignmentLog(GVar);

  // FIXME: ELF supports visibility

  SwitchToDataSection(SectionName.c_str());

  if (C->isNullValue() && !GVar->hasSection()) {
    if (!GVar->isThreadLocal() &&
        (GVar->hasInternalLinkage() || GVar->isWeakForLinker())) {
      if (Size == 0) Size = 1;   // .comm Foo, 0 is undefined, avoid it.

      if (GVar->hasInternalLinkage()) {
        O << "\t.lcomm " << name << "#," << Size
          << "," << (1 << Align);
        O << "\n";
      } else {
        O << "\t.common " << name << "#," << Size
          << "," << (1 << Align);
        O << "\n";
      }

      return;
    }
  }

  switch (GVar->getLinkage()) {
   case GlobalValue::LinkOnceLinkage:
   case GlobalValue::CommonLinkage:
   case GlobalValue::WeakLinkage:
    // Nonnull linkonce -> weak
    O << "\t.weak " << name << "\n";
    break;
   case GlobalValue::AppendingLinkage:
    // FIXME: appending linkage variables should go into a section of
    // their name or something.  For now, just emit them as external.
   case GlobalValue::ExternalLinkage:
    // If external or appending, declare as a global symbol
    O << TAI->getGlobalDirective() << name << "\n";
    // FALL THROUGH
   case GlobalValue::InternalLinkage:
    break;
   case GlobalValue::GhostLinkage:
    cerr << "GhostLinkage cannot appear in IA64AsmPrinter!\n";
    abort();
   case GlobalValue::DLLImportLinkage:
    cerr << "DLLImport linkage is not supported by this target!\n";
    abort();
   case GlobalValue::DLLExportLinkage:
    cerr << "DLLExport linkage is not supported by this target!\n";
    abort();
   default:
    assert(0 && "Unknown linkage type!");
  }

  EmitAlignment(Align);

  if (TAI->hasDotTypeDotSizeDirective()) {
    O << "\t.type " << name << ",@object\n";
    O << "\t.size " << name << "," << Size << "\n";
  }

  O << name << ":\t\t\t\t// " << *C << "\n";
  EmitGlobalConstant(C);
}


bool IA64AsmPrinter::doFinalization(Module &M) {
  // Print out module-level global variables here.
  for (Module::const_global_iterator I = M.global_begin(), E = M.global_end();
       I != E; ++I)
    printModuleLevelGV(I);

  // we print out ".global X \n .type X, @function" for each external function
  O << "\n\n// br.call targets referenced (and not defined) above: \n";
  for (std::set<std::string>::iterator i = ExternalFunctionNames.begin(),
       e = ExternalFunctionNames.end(); i!=e; ++i) {
    O << "\t.global " << *i << "\n\t.type " << *i << ", @function\n";
  }
  O << "\n\n";

  // we print out ".global X \n .type X, @object" for each external object
  O << "\n\n// (external) symbols referenced (and not defined) above: \n";
  for (std::set<std::string>::iterator i = ExternalObjectNames.begin(),
       e = ExternalObjectNames.end(); i!=e; ++i) {
    O << "\t.global " << *i << "\n\t.type " << *i << ", @object\n";
  }
  O << "\n\n";

  return AsmPrinter::doFinalization(M);
}

/// createIA64CodePrinterPass - Returns a pass that prints the IA64
/// assembly code for a MachineFunction to the given output stream, using
/// the given target machine description.
///
FunctionPass *llvm::createIA64CodePrinterPass(std::ostream &o,
                                              IA64TargetMachine &tm) {
  return new IA64AsmPrinter(o, tm, tm.getTargetAsmInfo());
}
