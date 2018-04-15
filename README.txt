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
X By default, lli calls the JIT compiler. That does not work outside of Xcode, and also might
  cause issues in the AppStore. 
   X Move to ForceInterpreter = true by default on iOS
   - Make this dependent on sideloading.
- replace stdout, stderr, stdin with ios_system's thread_stdout, thread_stderr...
   - in the Interpreter
   - in the JIT compiler (sideloading only)
   - work in progress, see raw_ostream.cpp 
   - works for stdout, fails if stdout is redirected
      - because at close time, thread_stdout == 0. But why??
      - only if thread_stdout was a file, opened with ">".
      - apparently also fails to write to it. It was opened, right? 
      - problem happen in raw_ostream::flush()
      - act only at write time (flush) and only if FD == STDOUT_FILENO / STDERR_FILENO
      - try putting llvm_shutdown back into ExternalFunctions.cpp

X replace progname() with argv[0] (progname is "OpenTerm", argv[0] is "clang")
   - Done, but now we get:
         clang: error: unable to execute command: Executable "clang" doesn't exist!
- Execute() (lib/Support/Unix/Program.inc) calls posix_spawn:
     - I can't create a fake posix_spawn, because file actions are a secret API.
     - so I undefined HAVE_POSIX_SPAWN and we go through fork + exec 
     - bonus: it's been tested before, so it should work
     - clang calls ExecuteAndWait(), defined in lib/Support/Program.cpp
     - lib/Support/Program.cpp contains ExecuteAndWait() and ExecuteNoWait()
     - both call Execute()
- check that memory is freed when LLVM exits, that flags are reset
- create dynamic libraries instead of executables
- create frameworks with the dynamic libraries


Analysis information:
---------------------
- By default, lli calls the JIT compiler (MCJIT). The JIT compiler only works if "get-task-allow" is defined.
- By default, this is true when running from Xcode, false as a standalone app
- It can be forced to true by editing the entitlements file, but only for sideloading (not on the AppStore)
- So we do "-force-interpreter=true" as a default setting on iOS
- Later, we might do the JIT branch. The interest is limited, though.




Also: apparently, Driver is not deleted when clang exits. 
   Doesn't break down things, but not reinitialized. llvm::sys::fs::getMainExecutable(Argv0, P)

Done, but now we get:
clang: error: unable to execute command: Executable "clang" doesn't exist!
   

LLVM iOS version wish list:
===========================

X run lli on a llvm intermediate representation, on an iOS device.
- ...with output on the application screen.
X generate llvm intermediate representation locally on iOS device
X ...and run it using lli
- ...without the need to specify "clang -cc1"
- add libFFI to lli, to load dynamic libraries
- install headers on iOS device, for compilation

X run lli on binary intermediate representation
- use lli to run a "serious" application (multiple source files, command line
  arguments)

- compile libcxx and libcxxabi for iOS as well.

