export ARCHS = arm64 arm64e
export CLI = 0
export TARGET = iphone:clang:14.5:15.0
export FINALPACKAGE=1
export THEOS_DEVICE_IP=192.168.0.101

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BadgeIndicator
BadgeIndicator_FILES = Tweak.x
BadgeIndicator_LIBRARIES = colorpicker
BadgeIndicator_EXTRA_FRAMEWORKS += Alderis
BadgeIndicator_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += badgeindicatorprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
