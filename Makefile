TARGET := iphone:clang:latest:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ioscli

ioscli_FILES = main.m cmd/cert.m cmd/profile.m
ioscli_CFLAGS = -fobjc-arc -I$(CURDIR)/include
ioscli_FRAMEWORKS = Security
ioscli_LDFLAGS = $(CURDIR)/lib/ManagedConfiguration.tbd
ioscli_CODESIGN_FLAGS = -Sentitlements.plist
ioscli_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk
