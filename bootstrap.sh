#! /bin/bash
# With contributions from Ian McDowell: https://github.com/IMcD23

# Bail out on error
set -e

LIBFFI_SRC=https://www.mirrorservice.org/sites/sourceware.org/pub/libffi/libffi-3.2.1.tar.gz

LLVM_SRCDIR=$(pwd)
OSX_BUILDDIR=$(pwd)/build_osx
IOS_BUILDDIR=$(pwd)/build_ios
IOS_SYSTEM=$(pwd)/../ios_system/
FFI_SRCDIR=$(pwd)/libffi-3.2.1/

IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)

# Parse arguments
for i in "$@"
do
case $i in
  -c|--clean)
    CLEAN=YES
  shift
  ;;
  *)
    # unknown option
  ;;
esac
done


# get clang, libcxx, libcxxabi
git submodule update --init --recursive

# Get libcxx and libcxxabi
# End downloading source

# compile for OSX (about 1h, 1GB of disk space)
if [ $CLEAN ]; then
  rm -rf $OSX_BUILDDIR
fi
if [ ! -d $OSX_BUILDDIR ]; then
  mkdir $OSX_BUILDDIR
fi
# building with -DLLVM_LINK_LLVM_DYLIB (= single big shared lib) 
# Easier to make a framework with
pushd $OSX_BUILDDIR
cmake -G Ninja \
-DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
-DLLVM_LINK_LLVM_DYLIB=ON \
-DCMAKE_BUILD_TYPE=Release \
..
ninja
popd

# get libcxx and libcxxabi out of the way:
# echo "Moving libcxx / libcxxabi out of the way:"
# rm -rf dontBuild
# mkdir dontBuild
# mv $LLVM_SRCDIR/projects/libcxx dontBuild
# mv $LLVM_SRCDIR/projects/libcxxabi dontBuild

# get libffi:
if [ ! -d $FFI_SRCDIR ]; then 
	echo "Downloading libffi-3.2.1" 
	curl $LIBFFI_SRC | tar xz 
	echo "Applying patch to libffi-3.2.1:"
	pushd $FFI_SRCDIR
	patch -p 1 < ../libffi-3.2.1_patch
	echo "Compiling libffi:"
	xcodebuild -project libffi.xcodeproj -target libffi-iOS -sdk iphoneos -arch arm64 -configuration Debug -quiet
	popd
fi
# compile ios_system where we want to find it:
echo "Compiling ios_system:" 
pushd $IOS_SYSTEM
xcodebuild -project ios_system.xcodeproj -target ios_system -sdk iphoneos -configuration Debug -quiet
popd

# TODO: some combination of build variables might allow us to build these too. 
# Right now, they fail. 
# Progress on libcxx with -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS  and -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF
# libcxx: we need include_next to include /usr/include/stdlib.h 
# Now, compile for iOS using the previous build:
# About 1h, 12 GB of disk space
# -DLLVM_ENABLE_THREADS=OFF is necessary to run commands multiple times
# -I${OSX_BUILDDIR}/include/c++/v1/
# Try to reduce inlining (doesn't work at compile time)
#  -D_LIBCPP_INLINE_VISIBILITY=\"\" -D_LIBCPP_ALWAYS_INLINE=\"\" -D_LIBCPP_EXTERN_TEMPLATE_INLINE_VISIBILITY=\"\"
if [ $CLEAN ]; then
  rm -rf $IOS_BUILDDIR
fi
if [ ! -d $IOS_BUILDDIR ]; then
  mkdir $IOS_BUILDDIR
fi
pushd $IOS_BUILDDIR
cmake -G Ninja \
-DLLVM_LINK_LLVM_DYLIB=ON \
-DLLVM_TARGET_ARCH=AArch64 \
-DLLVM_TARGETS_TO_BUILD="AArch64" \
-DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-darwin17.5.0 \
-DLLVM_ENABLE_FFI=ON \
-DLLVM_ENABLE_THREADS=OFF \
-DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
-DFFI_LIBRARY_PATH=${FFI_SRCDIR}/build/Debug-iphoneos/libffi.a \
-DFFI_INCLUDE_DIR=${FFI_SRCDIR}/build_iphoneos-arm64/include \
-DLLVM_TABLEGEN=${OSX_BUILDDIR}/bin/llvm-tblgen \
-DCLANG_TABLEGEN=${OSX_BUILDDIR}/bin/clang-tblgen \
-DCMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
-DCMAKE_C_COMPILER=${OSX_BUILDDIR}/bin/clang \
-DCMAKE_LIBRARY_PATH=${OSX_BUILDDIR}/lib/ \
-DCMAKE_INCLUDE_PATH=${OSX_BUILDDIR}/include/ \
-DCMAKE_C_FLAGS="-arch arm64 -target arm64-apple-darwin17.5.0  -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS  -I${OSX_BUILDDIR}/include/ -I${OSX_BUILDDIR}/include/c++/v1/ -I${IOS_SYSTEM} -miphoneos-version-min=11  " \
-DCMAKE_CXX_FLAGS="-arch arm64 -target arm64-apple-darwin17.5.0 -stdlib=libc++ -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS -I${OSX_BUILDDIR}/include/  -I${IOS_SYSTEM} -miphoneos-version-min=11 " \
-DCMAKE_SHARED_LINKER_FLAGS="-F${IOS_SYSTEM}/build/Debug-iphoneos/ -framework ios_system -lobjc " \
-DCMAKE_EXE_LINKER_FLAGS="-F${IOS_SYSTEM}/build/Debug-iphoneos/ -framework ios_system -lobjc " \
..
ninja
# Now build the static libraries for the executables:
rm -f lib/liblli.a
# Xcode gets confused if a static and a dynamic library share the same name:
rm -f lib/libclang_tool.a
rm -f lib/libopt.a
ar -r lib/liblli.a tools/lli/CMakeFiles/lli.dir/lli.cpp.o tools/lli/CMakeFiles/lli.dir/OrcLazyJIT.cpp.o 
ar -r lib/libclang_tool.a tools/clang/tools/driver/CMakeFiles/clang.dir/driver.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1_main.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1as_main.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1gen_reproducer_main.cpp.o  
ar -r lib/libopt.a  tools/opt/CMakeFiles/opt.dir/AnalysisWrappers.cpp.o tools/opt/CMakeFiles/opt.dir/BreakpointPrinter.cpp.o tools/opt/CMakeFiles/opt.dir/Debugify.cpp.o tools/opt/CMakeFiles/opt.dir/GraphPrinters.cpp.o tools/opt/CMakeFiles/opt.dir/NewPMDriver.cpp.o tools/opt/CMakeFiles/opt.dir/PassPrinters.cpp.o tools/opt/CMakeFiles/opt.dir/PrintSCC.cpp.o tools/opt/CMakeFiles/opt.dir/opt.cpp.o
# No need to make static libraries for these:
# llvm-link: tools/llvm-link/CMakeFiles/llvm-link.dir/llvm-link.cpp.o
# llvm-nm:  tools/llvm-nm/CMakeFiles/llvm-nm.dir/llvm-nm.cpp.o
# llvm-dis:  tools/llvm-dis/CMakeFiles/llvm-dis.dir/llvm-dis.cpp.o
popd
# Move libcxx, libcxxabi back in place:
# pushd projects
# mv $LLVM_SRCDIR/dontBuild/libcxx .
# mv $LLVM_SRCDIR/dontBuild/libcxxabi .
# popd
# And then build the frameworks from these static libraries:
xcodebuild -project frameworks/frameworks.xcodeproj -alltargets -sdk iphoneos -configuration Debug -quiet
cp build_ios/lib/libc++.1.0.dylib frameworks/libc++.1.dylib
cp build_ios/lib/libc++abi.1.0.dylib frameworks/libc++abi.1.dylib
