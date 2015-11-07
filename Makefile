ARCHS = armv7 arm64
include theos/makefiles/common.mk


TWEAK_NAME = BluetoothRename

BluetoothRename_FILES = Tweak.xm

BluetoothRename_FRAMEWORKS = UIKit AppSupport
BluetoothRename_LIBRARIES = rocketbootstrap
BluetoothRename_PRIVATE_FRAMEWORKS = Preferences
Depends:  com.rpetrich.rocketbootstrap
include $(THEOS_MAKE_PATH)/tweak.mk


