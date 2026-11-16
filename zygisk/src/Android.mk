LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := arm64-v8a
LOCAL_SRC_FILES := ocore_zygisk.cpp
LOCAL_CFLAGS := -std=c++17 -Wall -Wextra -fvisibility=hidden -O2
LOCAL_LDLIBS := -llog
include $(BUILD_SHARED_LIBRARY)
