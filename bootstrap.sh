#! /bin/bash
# With contributions from Ian McDowell: https://github.com/IMcD23

# Bail out on error
set -e

LIBFFI_SRC=https://www.mirrorservice.org/sites/sourceware.org/pub/libffi/libffi-3.2.1.tar.gz

LLVM_SRCDIR=$(pwd)
OSX_BUILDDIR=$(pwd)/build_osx
IOS_BUILDDIR=$(pwd)/build-iphoneos
SIM_BUILDDIR=$(pwd)/build-iphonesimulator
FFI_SRCDIR=$(pwd)/libffi/

echo "Downloading ios_system Framework:"
IOS_SYSTEM_VER="2.6"
HHROOT="https://github.com/holzschu"

echo "Downloading header file:"
curl -OL $HHROOT/ios_system/releases/download/$IOS_SYSTEM_VER/ios_error.h 

echo "Downloading ios_system Framework:"
rm -rf ios_system.xcframework
curl -OL $HHROOT/ios_system/releases/download/$IOS_SYSTEM_VER/ios_system.xcframework.zip
unzip ios_system.xcframework.zip
rm ios_system.xcframework.zip

OSX_SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)

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
echo "Compiling for OSX:"
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
-DLLVM_TARGETS_TO_BUILD="AArch64;X86;WebAssembly" \
-DLLVM_LINK_LLVM_DYLIB=ON \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_OSX_SYSROOT=${OSX_SDKROOT} \
-DCMAKE_C_COMPILER=$(xcrun --sdk macosx -f clang) \
-DCMAKE_CXX_COMPILER=$(xcrun --sdk macosx -f clang++) \
-DCMAKE_ASM_COMPILER=$(xcrun --sdk macosx -f cc) \
-DCMAKE_LIBRARY_PATH=${OSX_SDKROOT}/lib/ \
-DCMAKE_INCLUDE_PATH=${OSX_SDKROOT}/include/ \
..
ninja
popd
# libtool: where? /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool

# get libffi:
export M4=/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin//m4
echo "Compiling libffi:"
pushd $FFI_SRCDIR
# We need to patch libffi to allow compilation with Xcode 12, but only once (min iOS version >= 9)
# patch -p 1 < ../libffi.patch
echo "Compiling libffi:"
xcodebuild -project libffi.xcodeproj -target libffi-iOS -sdk iphoneos -arch arm64 -configuration Debug -quiet
xcodebuild -project libffi.xcodeproj -target libffi-iOS -sdk iphonesimulator -configuration Debug -quiet
popd

# Now, compile for iOS using the previous build:
# About 1h, 12 GB of disk space
# -DLLVM_ENABLE_THREADS=OFF is necessary to run commands multiple times
# -I${OSX_BUILDDIR}/include/c++/v1/
# Try to reduce inlining (doesn't work at compile time)
#  -D_LIBCPP_INLINE_VISIBILITY=\"\" -D_LIBCPP_ALWAYS_INLINE=\"\" -D_LIBCPP_EXTERN_TEMPLATE_INLINE_VISIBILITY=\"\"
echo "Compiling for iOS:"
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
-DLLVM_TARGETS_TO_BUILD="AArch64;X86;WebAssembly" \
-DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-darwin19.0.0 \
-DLLVM_ENABLE_FFI=ON \
-DLLVM_ENABLE_THREADS=OFF \
-DLLVM_ENABLE_TERMINFO=OFF \
-DLLVM_ENABLE_BACKTRACES=OFF \
-DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
-DFFI_LIBRARY_PATH=${FFI_SRCDIR}/build/Debug-iphoneos/libffi.a \
-DFFI_INCLUDE_DIR=${FFI_SRCDIR}/build_iphoneos-arm64/include \
-DLLVM_TABLEGEN=${OSX_BUILDDIR}/bin/llvm-tblgen \
-DCLANG_TABLEGEN=${OSX_BUILDDIR}/bin/clang-tblgen \
-DCMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
-DCMAKE_C_COMPILER=${OSX_BUILDDIR}/bin/clang \
-DCMAKE_LIBRARY_PATH=${OSX_BUILDDIR}/lib/ \
-DCMAKE_INCLUDE_PATH=${OSX_BUILDDIR}/include/ \
-DCMAKE_C_FLAGS="-arch arm64 -target arm64-apple-darwin19.0.0 -O2 -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS  -I${OSX_BUILDDIR}/include/ -I${OSX_BUILDDIR}/include/c++/v1/ -I${LLVM_SRCDIR} -miphoneos-version-min=11  " \
-DCMAKE_CXX_FLAGS="-arch arm64 -target arm64-apple-darwin19.0.0 -O2 -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS -I${OSX_BUILDDIR}/include/  -I${LLVM_SRCDIR} -miphoneos-version-min=11 " \
-DCMAKE_MODULE_LINKER_FLAGS="-nostdlib -F${LLVM_SRCDIR}/ios_system.xcframework/ios-arm64_armv7 -O2 -framework ios_system -lobjc -lc -lc++" \
-DCMAKE_SHARED_LINKER_FLAGS="-nostdlib -F${LLVM_SRCDIR}/ios_system.xcframework/ios-arm64_armv7 -O2 -framework ios_system -lobjc -lc -lc++" \
-DCMAKE_EXE_LINKER_FLAGS="-nostdlib -F${LLVM_SRCDIR}/ios_system.xcframework/ios-arm64_armv7 -O2 -framework ios_system -lobjc -lc -lc++" \
..
ninja
# We could add X86 to target architectures, but that increases the app size too much
# Now build the static libraries for the executables:
# -stdlib=libc++: not required with OSX > Mavericks
# -nostdlib: so ios_system is linked *before* libc and libc++ 
# try with: -fvisibility=hidden -fvisibility-inlines-hidden in CFLAGS for the warning
# -L lib = crashes every time (self-reference).
# lli crashes, but only lli. When creating main() (before the first line)
rm -f lib/liblli.a
rm -f lib/libllc.a
# Xcode gets confused if a static and a dynamic library share the same name:
rm -f lib/libclang_tool.a
rm -f lib/libopt.a
ar -r lib/libclang_tool.a tools/clang/tools/driver/CMakeFiles/clang.dir/driver.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1_main.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1as_main.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1gen_reproducer_main.cpp.o  
ar -r lib/libopt.a  tools/opt/CMakeFiles/opt.dir/AnalysisWrappers.cpp.o tools/opt/CMakeFiles/opt.dir/BreakpointPrinter.cpp.o tools/opt/CMakeFiles/opt.dir/Debugify.cpp.o tools/opt/CMakeFiles/opt.dir/GraphPrinters.cpp.o tools/opt/CMakeFiles/opt.dir/NewPMDriver.cpp.o tools/opt/CMakeFiles/opt.dir/PassPrinters.cpp.o tools/opt/CMakeFiles/opt.dir/PrintSCC.cpp.o tools/opt/CMakeFiles/opt.dir/opt.cpp.o
# No need to make static libraries for these:
# lli: tools/lli/CMakeFiles/lli.dir/lli.cpp.o 
# llvm-link: tools/llvm-link/CMakeFiles/llvm-link.dir/llvm-link.cpp.o
# llvm-nm:  tools/llvm-nm/CMakeFiles/llvm-nm.dir/llvm-nm.cpp.o
# llvm-ar:  tools/llvm-ar/CMakeFiles/llvm-ar.dir/llvm-ar.cpp.o
# llvm-dis:  tools/llvm-dis/CMakeFiles/llvm-dis.dir/llvm-dis.cpp.o
# llc: tools/llc/CMakeFiles/llc.dir/llc.cpp.o
# lld, wasm-ld, etc: done in Xcode.
rm -rf frameworks.xcodeproj
cp -r ../frameworks/frameworks.xcodeproj .
# And then build the frameworks from these static libraries:
xcodebuild -project frameworks.xcodeproj -alltargets -sdk iphoneos -configuration Release -quiet
popd

# Now, build for the simulator:
echo "Compiling for the simulator:"
if [ $CLEAN ]; then
  rm -rf $SIM_BUILDDIR
fi
if [ ! -d $SIM_BUILDDIR ]; then
  mkdir $SIM_BUILDDIR
fi
pushd $SIM_BUILDDIR
cmake -G Ninja \
-DLLVM_LINK_LLVM_DYLIB=ON \
-DLLVM_TARGET_ARCH=X86 \
-DLLVM_TARGETS_TO_BUILD="AArch64;X86;WebAssembly" \
-DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-apple-darwin19.0.0 \
-DLLVM_ENABLE_FFI=ON \
-DLLVM_ENABLE_THREADS=OFF \
-DLLVM_ENABLE_TERMINFO=OFF \
-DLLVM_ENABLE_BACKTRACES=OFF \
-DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
-DCMAKE_CROSSCOMPILING=TRUE \
-DFFI_LIBRARY_PATH=${FFI_SRCDIR}/build/Debug-iphonesimulator/libffi.a \
-DFFI_INCLUDE_DIR=${FFI_SRCDIR}/build_iphonesimulator-x86_64/include \
-DLLVM_TABLEGEN=${OSX_BUILDDIR}/bin/llvm-tblgen \
-DCLANG_TABLEGEN=${OSX_BUILDDIR}/bin/clang-tblgen \
-DCMAKE_OSX_SYSROOT=${SIM_SDKROOT} \
-DCMAKE_C_COMPILER=${OSX_BUILDDIR}/bin/clang \
-DCMAKE_LIBRARY_PATH=${OSX_BUILDDIR}/lib/ \
-DCMAKE_INCLUDE_PATH=${OSX_BUILDDIR}/include/ \
-DCMAKE_C_FLAGS="-target x86_64-apple-darwin19.0.0 -O2 -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS  -I${OSX_BUILDDIR}/include/ -I${OSX_BUILDDIR}/include/c++/v1/ -I${LLVM_SRCDIR} -mios-simulator-version-min=11.0  " \
-DCMAKE_CXX_FLAGS="-target x86_64-apple-darwin19.0.0 -O2 -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS -I${OSX_BUILDDIR}/include/  -I${LLVM_SRCDIR} -mios-simulator-version-min=11.0 " \
-DCMAKE_MODULE_LINKER_FLAGS="-nostdlib -F${LLVM_SRCDIR}/ios_system.xcframework/ios-i386_x86_64-simulator -O2 -framework ios_system -lobjc -lc -lc++" \
-DCMAKE_SHARED_LINKER_FLAGS="-nostdlib -F${LLVM_SRCDIR}/ios_system.xcframework/ios-i386_x86_64-simulator -O2 -framework ios_system -lobjc -lc -lc++" \
-DCMAKE_EXE_LINKER_FLAGS="-nostdlib -F${LLVM_SRCDIR}/ios_system.xcframework/ios-i386_x86_64-simulator -O2 -framework ios_system -lobjc -lc -lc++" \
..
ninja
# We could add X86 to target architectures, but that increases the app size too much
# Now build the static libraries for the executables:
# -stdlib=libc++: not required with OSX > Mavericks
# -nostdlib: so ios_system is linked *before* libc and libc++ 
# try with: -fvisibility=hidden -fvisibility-inlines-hidden in CFLAGS for the warning
# -L lib = crashes every time (self-reference).
# lli crashes, but only lli. When creating main() (before the first line)
rm -f lib/liblli.a
rm -f lib/libllc.a
# Xcode gets confused if a static and a dynamic library share the same name:
rm -f lib/libclang_tool.a
rm -f lib/libopt.a
ar -r lib/libclang_tool.a tools/clang/tools/driver/CMakeFiles/clang.dir/driver.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1_main.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1as_main.cpp.o tools/clang/tools/driver/CMakeFiles/clang.dir/cc1gen_reproducer_main.cpp.o  
ar -r lib/libopt.a  tools/opt/CMakeFiles/opt.dir/AnalysisWrappers.cpp.o tools/opt/CMakeFiles/opt.dir/BreakpointPrinter.cpp.o tools/opt/CMakeFiles/opt.dir/Debugify.cpp.o tools/opt/CMakeFiles/opt.dir/GraphPrinters.cpp.o tools/opt/CMakeFiles/opt.dir/NewPMDriver.cpp.o tools/opt/CMakeFiles/opt.dir/PassPrinters.cpp.o tools/opt/CMakeFiles/opt.dir/PrintSCC.cpp.o tools/opt/CMakeFiles/opt.dir/opt.cpp.o
# No need to make static libraries for these:
# lli: tools/lli/CMakeFiles/lli.dir/lli.cpp.o 
# llvm-link: tools/llvm-link/CMakeFiles/llvm-link.dir/llvm-link.cpp.o
# llvm-nm:  tools/llvm-nm/CMakeFiles/llvm-nm.dir/llvm-nm.cpp.o
# llvm-ar:  tools/llvm-ar/CMakeFiles/llvm-ar.dir/llvm-ar.cpp.o
# llvm-dis:  tools/llvm-dis/CMakeFiles/llvm-dis.dir/llvm-dis.cpp.o
# llc: tools/llc/CMakeFiles/llc.dir/llc.cpp.o
# lld, wasm-ld, etc: done in Xcode.
rm -rf frameworks.xcodeproj
cp -r ../frameworks/frameworks.xcodeproj .
# And then build the frameworks from these static libraries:
xcodebuild -project frameworks.xcodeproj -alltargets -sdk iphonesimulator -configuration Release -quiet
popd

# 6)
echo "Merging into xcframeworks:"

for framework in ar lld llc clang dis libLLVM link lli nm opt
do
   rm -rf $framework.xcframework
   xcodebuild -create-xcframework -framework build-iphoneos/build/Release-iphoneos/$framework.framework -framework build-iphonesimulator/build/Release-iphonesimulator/$framework.framework -output $framework.xcframework
   # while we're at it, let's compute the checksum:
   rm -f $framework.xcframework.zip
   zip -r $framework.xcframework.zip $framework.xcframework
   swift package compute-checksum $framework.xcframework.zip
done
