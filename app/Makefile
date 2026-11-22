TARGET := iphone:clang:latest:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IOSDumper
IOSDumper_FILES = main.m AppDelegate.mm ViewController.mm
IOSDumper_FRAMEWORKS = UIKit CoreGraphics
IOSDumper_PRIVATE_FRAMEWORKS = MobileCoreServices
IOSDumper_CFLAGS = -fobjc-arc
IOSDumper_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
