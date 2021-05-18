# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

BREAKPAD_SRC = $$PWD/../3rdparty/breakpad/src
INCLUDEPATH += $${BREAKPAD_SRC}

SOURCES += $${BREAKPAD_SRC}/client/minidump_file_writer.cc
SOURCES += $${BREAKPAD_SRC}/common/convert_UTF.cc
SOURCES += $${BREAKPAD_SRC}/common/string_conversion.cc

linux {
    SOURCES += $${BREAKPAD_SRC}/client/linux/crash_generation/crash_generation_client.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/dump_writer_common/thread_info.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/dump_writer_common/ucontext_reader.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/handler/exception_handler.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/handler/minidump_descriptor.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/microdump_writer/microdump_writer.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/minidump_writer/minidump_writer.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/minidump_writer/linux_dumper.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/minidump_writer/linux_ptrace_dumper.cc
    SOURCES += $${BREAKPAD_SRC}/client/linux/log/log.cc
    SOURCES += $${BREAKPAD_SRC}/common/linux/breakpad_getcontext.S
    SOURCES += $${BREAKPAD_SRC}/common/linux/elfutils.cc
    SOURCES += $${BREAKPAD_SRC}/common/linux/file_id.cc
    SOURCES += $${BREAKPAD_SRC}/common/linux/guid_creator.cc
    SOURCES += $${BREAKPAD_SRC}/common/linux/http_upload.cc
    SOURCES += $${BREAKPAD_SRC}/common/linux/linux_libc_support.cc
    SOURCES += $${BREAKPAD_SRC}/common/linux/memory_mapped_file.cc
    SOURCES += $${BREAKPAD_SRC}/common/linux/safe_readlink.cc

    HEADERS += $${BREAKPAD_SRC}/client/linux/crash_generation/crash_generation_client.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/dump_writer_common/thread_info.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/dump_writer_common/ucontext_reader.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/handler/exception_handler.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/handler/minidump_descriptor.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/microdump_writer/microdump_writer.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/minidump_writer/minidump_writer.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/minidump_writer/linux_dumper.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/minidump_writer/linux_ptrace_dumper.h
    HEADERS += $${BREAKPAD_SRC}/client/linux/log/log.h
    HEADERS += $${BREAKPAD_SRC}/common/linux/breakpad_getcontext.h
    HEADERS += $${BREAKPAD_SRC}/common/linux/elfutils.h
    HEADERS += $${BREAKPAD_SRC}/common/linux/file_id.h
    HEADERS += $${BREAKPAD_SRC}/common/linux/guid_creator.h
    HEADERS += $${BREAKPAD_SRC}/common/linux/http_upload.h
    HEADERS += $${BREAKPAD_SRC}/common/linux/linux_libc_support.h
    HEADERS += $${BREAKPAD_SRC}/common/linux/memory_mapped_file.h
    HEADERS += $${BREAKPAD_SRC}/common/linux/safe_readlink.h

    QMAKE_CXXFLAGS_WARN_ON += -Wno-error=missing-field-initializers
    QMAKE_CXXFLAGS_WARN_ON += -Wno-error=unused-parameter
    QMAKE_CXXFLAGS_WARN_ON += -Wno-error=sign-compare

    lss_header.target = $${BREAKPAD_SRC}/third_party/lss
    lss_header.commands = ln -sfT ../../../linux-syscall-support $${BREAKPAD_SRC}/third_party/lss
    QMAKE_EXTRA_TARGETS += lss_header
    QMAKE_DISTCLEAN += $$lss_header.target 
    PRE_TARGETDEPS += $$lss_header.target
}
