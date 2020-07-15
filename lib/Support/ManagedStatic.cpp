//===-- ManagedStatic.cpp - Static Global wrapper -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the ManagedStatic class and llvm_shutdown().
//
//===----------------------------------------------------------------------===//

#include "llvm/Support/ManagedStatic.h"
#include "llvm/Config/config.h"
#include "llvm/Support/Threading.h"
#include <cassert>

#ifdef __APPLE__
#include <TargetConditionals.h>
#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
#include <llvm-c/Support.h>
#include "ios_error.h"
#undef write
#undef exit
#endif
#endif

#include <mutex>
using namespace llvm;

static const ManagedStaticBase *StaticList = nullptr;
static std::recursive_mutex *ManagedStaticMutex = nullptr;
static llvm::once_flag mutex_init_flag;

static void initializeMutex() {
  ManagedStaticMutex = new std::recursive_mutex();
}

static std::recursive_mutex *getManagedStaticMutex() {
  llvm::call_once(mutex_init_flag, initializeMutex);
  return ManagedStaticMutex;
}

void ManagedStaticBase::RegisterManagedStatic(void *(*Creator)(),
                                              void (*Deleter)(void*)) const {
  assert(Creator);
  if (llvm_is_multithreaded()) {
    std::lock_guard<std::recursive_mutex> Lock(*getManagedStaticMutex());

    if (!Ptr.load(std::memory_order_relaxed)) {
      void *Tmp = Creator();

      Ptr.store(Tmp, std::memory_order_release);
      DeleterFn = Deleter;

      // Add to list of managed statics.
      Next = StaticList;
      StaticList = this;
    }
  } else {
    assert(!Ptr && !DeleterFn && !Next &&
           "Partially initialized ManagedStatic!?");
    Ptr = Creator();
    DeleterFn = Deleter;

    // Add to list of managed statics.
    Next = StaticList;
    StaticList = this;
  }
}

void ManagedStaticBase::destroy() const {
  assert(DeleterFn && "ManagedStatic not initialized correctly!");
  assert(StaticList == this &&
         "Not destroyed in reverse order of construction?");
  // Unlink from list.
  StaticList = Next;
  Next = nullptr;

  // Destroy memory.
  DeleterFn(Ptr);

  // Cleanup.
  Ptr = nullptr;
  DeleterFn = nullptr;
}

/// llvm_shutdown - Deallocate and destroy all ManagedStatic variables.
void llvm::llvm_shutdown() {
  std::lock_guard<std::recursive_mutex> Lock(*getManagedStaticMutex());

  while (StaticList)
    StaticList->destroy();
#if TARGET_OS_IPHONE
  // Reset signal handler(s) (except SIGUSR2, reserved by Python):
  (void)signal(SIGUSR1, SIG_DFL);
  (void)signal(SIGHUP, SIG_DFL);
  (void)signal(SIGINT, SIG_DFL);
  (void)signal(SIGPIPE, SIG_DFL);
  (void)signal(SIGTERM, SIG_DFL);
  (void)signal(SIGILL, SIG_DFL);
  (void)signal(SIGTRAP, SIG_DFL);
  (void)signal(SIGABRT, SIG_DFL);
  (void)signal(SIGFPE, SIG_DFL);
  (void)signal(SIGBUS, SIG_DFL);
  (void)signal(SIGSEGV, SIG_DFL);
  (void)signal(SIGQUIT, SIG_DFL);
  (void)signal(SIGINFO, SIG_DFL);
#endif
}

