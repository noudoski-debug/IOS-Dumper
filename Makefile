TARGET := iphone:clang:latest:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IOSDumper

IOSDumper_FILES = src/entry.mm src/dumper.cpp
IOSDumper_CFLAGS = -fobjc-arc
IOSDumper_CCFLAGS = -std=c++20
IOSDumper_LDFLAGS = -ldl

include $(THEOS_MAKE_PATH)/tweak.mk
