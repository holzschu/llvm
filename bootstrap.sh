#! /bin/bash
# With contributions from Ian McDowell: https://github.com/IMcD23

# Bail out on error
set -e

LIBCXX_SRC=http://releases.llvm.org/6.0.0/libcxx-6.0.0.src.tar.xz
LIBCXXABI_SRC=http://releases.llvm.org/6.0.0/libcxxabi-6.0.0.src.tar.xz

LLVM_SRCDIR=$(pwd)/llvm_src
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


# get clang
git submodule update --init --recursive

# Get libcxx and libcxxabi
pushd projects

if [ ! -d libcxx ]; then
  mkdir libcxx
  curl $LIBCXX_SRC | tar xz -C libcxx --strip-components 1
fi
if [ ! -d libcxxabi ]; then
  mkdir libcxxabi
  curl $LIBCXXABI_SRC | tar xz -C libcxxabi --strip-components 1
fi
popd
# End downloading source

# compile for OSX (about 3h, 8GB of disk space)
if [ $CLEAN ]; then
  rm -rf $OSX_BUILDDIR
fi
if [ ! -d $OSX_BUILDDIR ]; then
  mkdir $OSX_BUILDDIR
fi
pushd $OSX_BUILDDIR
cmake -DBUILD_SHARED_LIBS=ON \
..
cmake --build .
popd

# get libcxx and libcxxabi out of the way:
rm -rf dontBuild
mkdir dontBuild
mv llvm_src/projects/libcxx dontBuild
mv llvm_src/projects/libcxxabi dontBuild
# TODO: some combination of build variables might allow us to build these too. 
# Right now, they fail. Maybe CFLAGS with: -D__need_size_t -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS 
# If we can compile 
# Now, compile for iOS using the previous build:
# About 24h, 5 GB of disk space
# Flags you could use: LLVM_LINK_LLVM_DYLIB and BUILD_SHARED_LIBS, to make everything use dynamic libraries
# (I did not test these)

if [ $CLEAN ]; then
  rm -rf $IOS_BUILDDIR
fi
if [ ! -d $IOS_BUILDDIR ]; then
  mkdir $IOS_BUILDDIR
fi
pushd $IOS_BUILDDIR
cmake -DBUILD_SHARED_LIBS=ON -DLLVM_TARGET_ARCH=AArch64 \
-DLLVM_TARGETS_TO_BUILD=AArch64 \
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
-DCMAKE_SHARED_LINKER_FLAGS="-F${IOS_SYSTEM}/build/Debug-iphoneos/ -framework ios_system"\
-DCMAKE_EXE_LINKER_FLAGS="-F${IOS_SYSTEM}/build/Debug-iphoneos/ -framework ios_system"\
$LLVM_SRCDIR
popd
