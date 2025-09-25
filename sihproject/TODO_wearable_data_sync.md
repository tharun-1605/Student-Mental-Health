# TODO: Fix Wearable Data Syncing

## Issue
The watch is connected but data like sleep, heart rate, oxygen, stress levels, and steps count are not fetching and syncing to the app.

## Plan
1. Extend wearable_service.dart to support fetching steps, sleep, oxygen, and stress data from the watch via BLE characteristics.
2. Update health_data_service.dart to integrate with wearable_service.dart for direct data fetching from the watch.
3. Add BLE characteristics and parsing logic for oxygen (SpO2), stress, and steps data.
4. Ensure proper data syncing to Firestore for all data types.
5. Add error handling and logging for data fetching issues.
6. Test the full data flow from watch to app.

## Steps
- [x] Add streams and controllers for oxygen, stress, and steps data in wearable_service.dart
- [x] Implement BLE characteristic discovery and reading for oxygen (SpO2), stress, and steps
- [x] Add parsing logic for oxygen, stress, and steps data values
- [x] Update health_data_service.dart to fetch data from wearable_service.dart in addition to health package
- [x] Modify syncHealthData() to include oxygen, stress, and steps data
- [x] Add oxygen and stress data types to health package requests if supported (Note: Not supported by health package v13.1.4, using wearable service instead)
- [ ] Test data fetching and syncing for all metrics
- [ ] Verify data storage in Firestore
