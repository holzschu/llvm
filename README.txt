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

Once you have the binaries inside your app, you need to provide the header files. I copied the ones from the Xcode iPhone SDK into ~/usr/include, and the ones from build_ios/lib/clang/7.0.0/include/ into ~/lib/clang/7.0.0/include/ This will need some thinking.

I welcome all help on this project, including on this README file. 

iOS: how to compile a command?
==============================

It's a multi-step process.

1) compile each source file (*.c) using:
clang -S -emit-llvm -I ~/lib/clang/7.0.0/include -I ~/usr/include -Wno-nullability-completeness -D_FORTIFY_SOURCE=0 file.c
(you can place all the options into a config file, and use 'clang --config ~/clang.cfg file.c' instead)

This produces a 'file.ll' file, containing LLVM bitcode for file.c

(if you are compiling packages that use 'configure', you will need to create your own config.h, and add -DHAVE_CONFIG_H)

2) link the files together:
llvm-link -only-needed -o=executable.bc *.ll

This produces an 'executable.bc' file, containing (binary) LLVM bitcode for all the source files.

3) execute, using the LLVM interpreter:

lli executable.bc <arguments> 

LLI (LLVM Interpreter) can run both a JIT compiler and an interpreter. Currently, the JIT compiler only works if the main application was started by Xcode on your Mac. So the default mode is to run  the interpreter (-force-interpreter=true). This is the opposite of the default mode for LLI. If you want to run the JIT compiler, use '-force-interpreter=false'. 

The JIT compiler is at least 3 times faster than the interpreter, so it would be great to be able to run it on independent apps. 

If it doesn't work:
-------------------

This is a very experimental work. The interpreter, often, does not work. Here are a few of the issues encountered, and how I solved them:

- "Code generator does not support intrinsic function 'llvm.objectsize.i64.pi08'": compile with -D_FORTIFY_SOURCE=0 
- crash when running 'bsearch': compile with bsearch.c https://opensource.apple.com/source/xnu/xnu-1228/libsa/bsearch.c
- crash when running 'qsort': compile with qsort.c https://opensource.apple.com/source/xnu/xnu-344/bsd/kern/qsort.c

External functions are called using libFFI, and libFFI has problems with pointer manipulation (that's what happens with bsearch and qsort). 

- "Unable to allocate memory for common symbols": (more likely with the JIT) sorry, no ideas.
- "Unknown constant pointer type!": beats me. 


LLVM iOS version TODO list:
===========================

- make it easier to add llvm binaries to existing iOS projects, with associated dylibs
X added external functions for exit, print, abort, system, exec... (both interpreter and JIT)
- check that memory is freed when LLVM exits, that all flags are reset
- create a "fake libc" for functions that don't work with FFI (qsort, bsearch,...)
- create dynamic libraries instead of executables
- create frameworks with the dynamic libraries

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
X use lli to run a "serious" application (multiple source files, command line
  arguments)

- compile libcxx and libcxxabi for iOS as well --> required?

