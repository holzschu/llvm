Low Level Virtual Machine  for iOS (LLVM)
=========================================

This directory and its subdirectories contain a forked source code 
for LLVM, a toolkit for the construction of highly optimized compilers,
optimizers, and runtime environments.

LLVM is open source software. You may freely distribute it under the terms of
the license agreement found in LICENSE.txt.

Please see the documentation provided in docs/ for further
assistance with LLVM, and in particular docs/GettingStarted.rst for getting
started with LLVM and docs/README.txt for an overview of LLVM's
documentation setup.

If you are writing a package for LLVM, see docs/Packaging.rst for our
suggestions.

iOS version specific information
================================

This is a very experimental port. It's is designed to work inside ios_system
(https://github.com/holzschu/ios_system), which itself is supposed to be 
embedded inside shell applications such as OpenTerm or Blink:
- https://github.com/louisdh/terminal
- https://github.com/holzschu/blink

Compilation of the entire package takes around 20h (divided by the number of 
cores you can give to the compiler). For this reason, even the scripts are 
not fully guaranteed to work. 

The steps for compilation are:
- get clang as a submodule: 
git submodule update --init --recursive

- get libcxx and libcxxabi as packages
- compile LLVM, clang, libcxx and libcxxabi for OSX
- move libcxx and libcxxabi out of the way
- compile LLVM and clang for iOS (that's the long step)

"bootstrap.sh" in this directory takes care of all these steps. Remember, 
you have time for a long walk in the woods while it compiles. "build_ios.sh"
does only the "compile LLVM and clang for iOS" part. This is the part I expect
to be doing multiple times.

Once you have compiled everything, add clang and lli to the list of embedded 
binaries, along with all the required dynamic libraries (a lot of them). 
See `project.pbxproj` in this directory for an example. 

I welcome all help on this project, including on this README file. 

LLVM iOS version TODO list:
===========================

- make it easier to add llvm binaries to existing iOS projects, with associated dylibs
X replace all calls to exit() with calls to ios_exit()
- replace stdout, stderr, stdin with ios_system's thread_stdout, thread_stderr...
X replace progname() with argv[0] (progname is "OpenTerm", argv[0] is "clang")
   - Done, but now we get:
         clang: error: unable to execute command: Executable "clang" doesn't exist!
- make sure posix_spawn works:
     - clang calls ExecuteAndWait(), defined in lib/Support/Program.cpp
     - Execute() calls posix_spawn()
     - Execute() is static, defined in lib/Support/Unix/Program.inc
     - the rest of LLVM calls either ExecuteAndWait() or ExecuteNoWait()
     - program name probably obtained by "auto ClangBinary = sys::findProgramByName("clang", Dir);"
       (in tools/clang//tools/clang-offload-bundler/ClangOffloadBundler.cpp)
     - unless it's from Program.str().c_str() in ./lib/Support/Unix/Program.inc
- work on calls to fork/exec, posix_spawn, etc.
- check that memory is freed when LLVM exits, that flags are reset
- create dynamic libraries instead of executables
- create frameworks with the dynamic libraries


Analysis information:
---------------------
- lli calls the JIT compiler. "-force-interpreter=true" fails on "LLVM ERROR: Tried to execute an unknown external function: my_exit" (not impossible to solve)

- if we use the JIT compiler, EE (ExecutionEngine) is called. Otherwise (-force-interpreter=true), Interpreter is called. 
Each of them deals with external functions differently.


Line 814 in Job.cpp: Executable is "OpenTerm"
line 4795 in Clang.cpp: Exec is "OpenTerm"
line 4661 in Clang.cpp: const char *Exec = D.getClangProgramPath();
line 314 in Driver.h: return ClangExecutable.c_str(); ClangExecutable is "OpenTerm"
line 462 in driver.cpp: Driver TheDriver(Path, llvm::sys::getDefaultTargetTriple(), Diags);
line 439 in driver.cpp: std::string Path = GetExecutablePath(argv[0], CanonicalPrefixes);
line 55 in driver.cpp: llvm::sys::fs::getMainExecutable(Argv0, P) where P is a pointer to a function

Also: apparently, Driver is not deleted when clang exits. 
   Doesn't break down things, but not reinitialized. llvm::sys::fs::getMainExecutable(Argv0, P)

Done, but now we get:
clang: error: unable to execute command: Executable "clang" doesn't exist!
   

LLVM iOS version wish list:
===========================

X run lli on a llvm intermediate representation, on an iOS device.
- ...with output on the application screen.
- generate llvm intermediate representation locally on iOS device
- ...and run it using lli

- run lli on binary intermediate representation
- use lli to run a "serious" application (multiple source files, command line
  arguments)

- compile libcxx and libcxxabi for iOS as well.






