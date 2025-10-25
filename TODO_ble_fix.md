# BLE Heart Rate Reading Fix

## Problem
- Characteristic ae01 does not support NOTIFY (CCCD not found) nor READ (READ property not supported).
- Code attempts notify, fails, falls back to periodic read, which also fails.
- Results in repeated errors and no heart rate data.
- Now using ae02, but receiving empty data (value: []), resulting in heart rate 0.

## Root Cause
- Code does not check characteristic properties before attempting operations.
- Incorrectly assumes ae01/ae02 are heart rate characteristics.
- Data parsing doesn't handle Boat Crest specific format.
- Notification setup succeeds but data is empty.

## Solution
1. Add property checks before attempting notify or read.
2. Improve characteristic selection to prioritize known working UUIDs.
3. Enhance data parsing for Boat Crest format.
4. Add better error handling and logging for empty data.

## Steps
1. Modify startHeartRateMonitoring to check properties and improve selection.
2. Update _parseHeartRate to handle Boat Crest data format.
3. Add logging for received data to debug empty values.
4. Test with the device.
