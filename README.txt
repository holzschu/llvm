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
- get clang and lld as submodules: git submodule update --init --recursive
- get libcxx and libcxxabi as packages
- compile LLVM, clang, lld, libcxx and libcxxabi for OSX
- move libcxx and libcxxabi out of the way
- get libffi and compile it
- compile LLVM and clang for iOS (that's the long step)

"bootstrap.sh" in this directory takes care of all these steps. Remember, 
you have time for a long walk in the woods while it compiles. 

Once you have compiled everything, add clang and lli to the list of embedded 
binaries, along with all the required dynamic libraries (a lot of them). 
See `project.pbxproj` in this directory for an example. 

Commands in `project.pbxproj`: clang, lli, llvm-link, llvm-nm, llvm-dis 

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
   X in the Interpreter
   - in the JIT compiler (sideloading only)

X replace progname() with argv[0] (progname is "OpenTerm", argv[0] is "clang")

X Execute() (lib/Support/Unix/Program.inc) calls posix_spawn:
     - I can't create a fake posix_spawn, because file actions are a secret API.
     X so I undefined HAVE_POSIX_SPAWN and we go through fork + exec 
- check that memory is freed when LLVM exits, that all flags are reset
- create dynamic libraries instead of executables
- create frameworks with the dynamic libraries

X add libFFI to the interpreter, for aux functions:
   - function name in IR not exactly function name in library. 
   - in sys::DynamicLibrary::SearchForAddressOfSymbol()
   - we try 3 times: one with the name, one with removing the '\x01' in front, one with removing the '_' in front. 
   - it works, but why did we have to to that?
   - map std* to thread_std* in DynamicLibrary.inc, map thread_std* to the external values.

- we can't generate llvm IR while linking, but we can link several IR files with llvm-link
- how to add new libraries to IR file? How to load them? "nm" works on embedded binaries.
- where to place include files for on-system compilation? 

- stability issues when using nm <library> | grep " T ".  Crashes occasionally with a SIGPIPE. Could be caused by stderr being unbuffered, while stdout is buffered. Tries to write to stdout, with Unbuffered == true. Means stdout has been closed. 

Analysis information:
---------------------
- By default, lli calls the JIT compiler (MCJIT). The JIT compiler only works if "get-task-allow" is defined.
- By default, this is true when running from Xcode, false as a standalone app
- It can be forced to true by editing the entitlements file, but only for sideloading (not on the AppStore)
- So we do "-force-interpreter=true" as a default setting on iOS
- Later, we might do the JIT branch. The interest is limited, though.


Also: apparently, Driver is not deleted when clang exits. 
   Doesn't break down things, but not reinitialized. llvm::sys::fs::getMainExecutable(Argv0, P)

Compile files with:
~/src/Xcode_iPad/llvm/build_osx/bin/clang -S -emit-llvm -arch arm64 -target arm64-apple-darwin17.5.0 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS11.3.sdk -I ../.. mkdir.c
   
Extract bitcode from compiled apps with bitcode_retriever: https://github.com/AlexDenisov/bitcode_retriever
It will extract one bc file for each C file in the original program. The ll file (extracted with llvm-dis) is identical to the file generated with -emit-llvm. 

LLVM iOS version wish list:
===========================

X run lli on a llvm intermediate representation, on an iOS device.
X ...with output on the application screen.
X generate llvm intermediate representation locally on iOS device
X ...and run it using lli
X ...without the need to specify "clang -cc1"
X add libFFI to lli, to load dynamic libraries
X install headers on iOS device, for compilation
- load more dynamic libraries, as needed.

X run lli on binary intermediate representation
- use lli to run a "serious" application (multiple source files, command line
  arguments)

- compile libcxx and libcxxabi for iOS as well.

