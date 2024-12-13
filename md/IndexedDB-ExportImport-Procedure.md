# Procedure to Export and Import IndexedDB Data

## **Export Data from IndexedDB**

This procedure explains how to export data from a specific IndexedDB database and object store in your browser.

### **Steps to Export Data**

1. **Use the Following Code**:
   Execute the following script in the browser's Developer Tools Console:

   ```javascript
   const dbName = '<db-name>';
   const storeName = '<store-name>';

   let request = indexedDB.open(dbName);

   request.onsuccess = function (event) {
       let db = event.target.result;
       let transaction = db.transaction(storeName, 'readonly');
       let store = transaction.objectStore(storeName);
       let allData = store.getAll();

       allData.onsuccess = function () {
           console.log(JSON.stringify(allData.result));
           // Copy the output from the console
       };
   };

   request.onerror = function (event) {
       console.error('Error opening database:', event.target.errorCode);
   };
   ```

2. **Copy the Exported Data**:
   - Open Developer Tools (`F12` or `Ctrl+Shift+I`) in your browser.
   - Go to the **Console** tab.
   - Run the script above.
   - Once the `allData.onsuccess` event fires, the data will be logged in JSON format in the console.
   - Copy the output JSON array.

---

## **Import Data into IndexedDB**

This procedure explains how to import the exported data into a specific IndexedDB database and object store.

### **Steps to Import Data**

1. **Prepare Your Data**:
   - Ensure you have the exported JSON data from the previous step.
   - Paste the JSON array into the `importedData` variable in the script below.

2. **Use the Following Code**:
   Execute the following script in the browser's Developer Tools Console:

   ```javascript
   const dbName = '<db-name>';
   const storeName = '<store-name>';

   const importedData = [/* Paste your exported JSON array here */];

   let request = indexedDB.open(dbName);

   request.onsuccess = function (event) {
       let db = event.target.result;
       let transaction = db.transaction(storeName, 'readwrite');
       let store = transaction.objectStore(storeName);

       importedData.forEach(item => {
           store.add(item);
       });

       transaction.oncomplete = function () {
           console.log('Data imported successfully');
       };

       transaction.onerror = function (event) {
           console.error('Error importing data:', event.target.errorCode);
       };
   };

   request.onerror = function (event) {
       console.error('Error opening database:', event.target.errorCode);
   };
   ```

3. **Verify the Import**:
   - Open Developer Tools.
   - Go to the **Application** tab.
   - Navigate to **Storage > IndexedDB**.
   - Confirm that the data is present in the specified object store.

---

## **Important Notes**
- The `storeName` in the script must match the name of the object store you are working with.
- Ensure the data structure matches the object store schema, especially if it uses a specific `keyPath`.
- Handle potential errors, such as version mismatches or missing object stores, by upgrading the database schema if needed.