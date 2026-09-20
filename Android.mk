#
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),pdx246)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
