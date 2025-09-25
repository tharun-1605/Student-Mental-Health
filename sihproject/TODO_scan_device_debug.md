# TODO: Debug Device Scanning Issue

## Steps to Debug and Fix "No Device Listing" Issue

1. **Add debug logs in wearable_service.dart startScan method**
   - Log Bluetooth availability and enabled status
   - Log permission request results
   - Log scan start and results
   - Log any exceptions during scanning

2. **Add error handling in stress_monitoring_dashboard.dart**
   - Wrap startScan call in try-catch
   - Show error messages to user via SnackBar if scan fails
   - Log errors for debugging

3. **Add logs in discoveredDevices stream listener**
   - Log when devices are discovered
   - Log device details (name, id, etc.)

4. **Test scanning with logs**
   - Run the app and check console logs
   - Verify permissions are granted
   - Check if Bluetooth is enabled
   - See if scan results are received

5. **Fix issues based on logs**
   - If permissions denied, ensure proper permission handling
   - If Bluetooth disabled, prompt user to enable
   - If no devices found, check device discoverability or range
   - If stream not updating, fix subscription or controller issues

6. **Remove debug logs after fixing**
   - Clean up print statements once issue is resolved
