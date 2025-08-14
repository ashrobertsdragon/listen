#!/bin/bash

# Patch background.js to update the endpoint with the upload Function URL
sed -i "s|let endpoint = null;|let endpoint = '${upload_function_url}';|" /path/to/background.js
