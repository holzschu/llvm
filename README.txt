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
   X in the Interpreter
   - in the JIT compiler (sideloading only)

X replace progname() with argv[0] (progname is "OpenTerm", argv[0] is "clang")
   - Done. Now we need "ld" for some programs.
X Execute() (lib/Support/Unix/Program.inc) calls posix_spawn:
     - I can't create a fake posix_spawn, because file actions are a secret API.
     X so I undefined HAVE_POSIX_SPAWN and we go through fork + exec 
- check that memory is freed when LLVM exits, that flags are reset
- create dynamic libraries instead of executables
- create frameworks with the dynamic libraries

- add libFFI to the interpreter, for aux libraries (compiling)
- we can't generate llvm IR while linking, but we can link several IR files with llvm-link
- so question is: how to call system functions / aux libraries? With FFI? 

Analysis information:
---------------------
- By default, lli calls the JIT compiler (MCJIT). The JIT compiler only works if "get-task-allow" is defined.
- By default, this is true when running from Xcode, false as a standalone app
- It can be forced to true by editing the entitlements file, but only for sideloading (not on the AppStore)
- So we do "-force-interpreter=true" as a default setting on iOS
- Later, we might do the JIT branch. The interest is limited, though.


Also: apparently, Driver is not deleted when clang exits. 
   Doesn't break down things, but not reinitialized. llvm::sys::fs::getMainExecutable(Argv0, P)

Compile auxiliary files with:
~/src/Xcode_iPad/llvm/build_osx/bin/clang -emit-llvm-bc -arch arm64 -target arm64-apple-darwin17.5.0 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS11.3.sdk -I ../.. -F ../../build/Debug-iphoneos/ -framework ios_system mkdir.c
   

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

