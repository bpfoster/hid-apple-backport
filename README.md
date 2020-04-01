
## Overview
This gets my Apple Magic Keyboard fully functional in CentOS 7.

## Problem Description
Upon plugging in the keyboard, it is bound to the hid-generic driver.
```
[  127.735562] usb 3-1.6: new full-speed USB device number 6 using xhci_hcd
[  127.928711] usb 3-1.6: New USB device found, idVendor=05ac, idProduct=026c, bcdDevice= 8.52
[  127.928720] usb 3-1.6: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[  127.928727] usb 3-1.6: Product: Magic Keyboard with Numeric Keypad
[  127.928732] usb 3-1.6: Manufacturer: Apple Inc.
[  127.928737] usb 3-1.6: SerialNumber: XXXXXXXXXXXXXXXXX
[  127.942777] hid-generic 0003:05AC:026C.0006: hiddev0,hidraw1: USB HID v1.10 Device [Apple Inc. Magic Keyboard with Numeric Keypad] on usb-0000:0b:00.0-1.6/input0
[  127.945347] input: Apple Inc. Magic Keyboard with Numeric Keypad as /devices/pci0000:00/0000:00:1c.0/0000:03:00.0/0000:04:01.0/0000:06:00.0/0000:07:04.0/0000:09:00.0/0000:0a:01.0/0000:0b:00.0/usb3/3-1/3-1.6/3-1.6:1.1/input/input29
[  127.997566] hid-generic 0003:05AC:026C.0007: input,hiddev0,hidraw2: USB HID v1.10 Keyboard [Apple Inc. Magic Keyboard with Numeric Keypad] on usb-0000:0b:00.0-1.6/input1
```

This causes the `Fn` key to be completely disabled, and therefore cannot use it as a modifier.

Why is `hid-generic` binding to the device when there is `hid-apple`?  Device drivers register the idVendor/idProduct tuples that they support.  This is a relatively new keyboard, and support for this ProductID was [added in Kernel 4.19](https://github.com/torvalds/linux/commit/ee345492437043a79db058a3d4f029ebcb52089a) (CentOS 7 ships with Kernel 3.10).


Literally, all the driver needs is to add the idVendor/idProduct tuple (in this case `0x05AC`/`0x026C`).


Because the hid and hid-apple drivers are builtin to the kernel, I cannot just backport the changes and replace the .ko file.


## Solution
So, I copied `hid-apple.c` to `hid-apple2.c`, removed all the existing devices from the table and added in the new one that I need.  We can then compile this to a new `hid-apple2` driver, which functions properly for this keyboard.

We build and insert the driver with DKMS so that future kernel updates will cause the custom module to be rebuilt.

Kernel module related files can be found in the `kernel/` directory.


Great, so now we have a functional driver for this keyboard, but it's still binding to `hid-generic`.  Despite the code programmatically registering its supported device tables (which might make you think this is all dynamic), prior to Kernel 4.16, all these device IDs had to coded in to `hid-core.c` as having special drivers so that `hid-generic` wouldn't handle it!  [See this post for more](https://stackoverflow.com/questions/3389192/register-bind-match-a-device-with-a-driver/54299197#54299197).


How do we then get `hid-apple2` to handle the keyboard?  Well, we add a udev rule that fires when a device with this idVendor/idProduct tuple is added.  It unbinds the device from `hid-generic`, and binds to `hid-apple2`.  See the `udev/` folder for the actual rule.


Everything's perfect now.  A slight annoyance is that the `hid-apple` driver sets the function keys to be the multimedia keys by default.  I want that switched, so we set the `fnmode` [option to 2](https://github.com/torvalds/linux/blob/v3.10/drivers/hid/hid-apple.c#L40).  To make this persist across reboots, a modprobe rule is added - see the `modprobe/` directory.


## Misc
This seems like an overly complicated solution to a trivial problem.  I'm probably missing something stupid simple.

I found references to the `new_id` sysfs, which makes it sound like we could just register the device with `hid-apple` like so:
```
echo "05ac 026c 0 05ac 0220" | sudo tee /sys/bus/hid/drivers/apple/new_id
```

But, the device still binds to `hid-generic` and trying the manual unbind/bind process currently employed by that udev rule doesn't work either - the bind returns "No such device".  Not sure why that doesn't work.
