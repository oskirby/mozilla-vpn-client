/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "commandlineparser.h"
#include "leakdetector.h"

#ifdef MVPN_CRASHREPORT
#  if defined(MVPN_ANDROID) || defined(MVPN_LINUX)
#    include "client/linux/handler/exception_handler.h"
#  else
#    error "Crash reporting not supported for this platform"
#  endif

static bool dumpCallback(const google_breakpad::MinidumpDescriptor& descriptor,
                         void* context, bool succeeded) {
  /* TODO: Some kind of fork/exec magic to handle the minidump */
  Q_UNUSED(context);
  printf("Breakpad dump path: %s\n", descriptor.path());
  return succeeded;
}

#endif

int main(int argc, char* argv[]) {
#ifdef MVPN_CRASHREPORT
  google_breakpad::MinidumpDescriptor descriptor("/tmp");
  google_breakpad::ExceptionHandler eh(descriptor, NULL, dumpCallback, NULL,
                                       true, -1);
#endif
#ifdef QT_DEBUG
  LeakDetector leakDetector;
  Q_UNUSED(leakDetector);
#endif

  CommandLineParser clp;
  return clp.parse(argc, argv);
}
