#! /bin/bash
# With contributions from Ian McDowell: https://github.com/IMcD23

# Bail out on error
set -e

LLVM_SRCDIR=$(pwd)
OSX_BUILDDIR=$(pwd)/build_osx
IOS_BUILDDIR=$(pwd)/build_ios
IOS_SYSTEM=$(pwd)/../ios_system/

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


if [ $CLEAN ]; then
  rm -rf $IOS_BUILDDIR
fi
if [ ! -d $IOS_BUILDDIR ]; then
  mkdir $IOS_BUILDDIR
fi
pushd $IOS_BUILDDIR
cmake -DBUILD_SHARED_LIBS=ON -DLLVM_TARGET_ARCH=AArch64 \
-DLLVM_TARGETS_TO_BUILD="AArch64" \
-DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-darwin17.5.0 \
-DLLVM_ENABLE_THREADS=OFF \
-DLLVM_TABLEGEN=${OSX_BUILDDIR}/bin/llvm-tblgen \
-DCLANG_TABLEGEN=${OSX_BUILDDIR}/bin/clang-tblgen \
-DCMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
-DCMAKE_C_COMPILER=${OSX_BUILDDIR}/bin/clang \
-DCMAKE_LIBRARY_PATH=${OSX_BUILDDIR}/lib/ \
-DCMAKE_INCLUDE_PATH=${OSX_BUILDDIR}/include/ \
-DCMAKE_C_FLAGS="-arch arm64 -target arm64-apple-darwin17.5.0 -I${OSX_BUILDDIR}/include/ -I/Users/holzschu/src/Xcode_iPad/ios_system/ -miphoneos-version-min=11" \
-DCMAKE_CXX_FLAGS="-arch arm64 -target arm64-apple-darwin17.5.0 -I${OSX_BUILDDIR}/include/c++/v1/ -I${IOS_SYSTEM} -miphoneos-version-min=11" \
-DCMAKE_SHARED_LINKER_FLAGS="-F${IOS_SYSTEM}/build/Debug-iphoneos/ -framework ios_system" \
-DCMAKE_EXE_LINKER_FLAGS="-F${IOS_SYSTEM}/build/Debug-iphoneos/ -framework ios_system" \
..
cmake --build . 
popd
