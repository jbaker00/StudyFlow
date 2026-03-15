#!/bin/sh
# ci_post_clone.sh — runs after Xcode Cloud clones the repo.
# Generates GoogleService-Info.plist from environment variables
# set in the Xcode Cloud workflow environment variables UI.
#
# Required environment variables (set in Xcode Cloud → Workflow → Environment):
#   FIREBASE_API_KEY
#   FIREBASE_CLIENT_ID
#   FIREBASE_REVERSED_CLIENT_ID
#   FIREBASE_GCM_SENDER_ID
#   FIREBASE_GOOGLE_APP_ID
#   FIREBASE_PROJECT_ID
#   FIREBASE_STORAGE_BUCKET
#   FIREBASE_BUNDLE_ID

set -e

PLIST_PATH="${CI_PRIMARY_REPOSITORY_PATH}/DrKimmons/GoogleService-Info.plist"

echo "Generating GoogleService-Info.plist..."

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CLIENT_ID</key>
	<string>${FIREBASE_CLIENT_ID}</string>
	<key>REVERSED_CLIENT_ID</key>
	<string>${FIREBASE_REVERSED_CLIENT_ID}</string>
	<key>API_KEY</key>
	<string>${FIREBASE_API_KEY}</string>
	<key>GCM_SENDER_ID</key>
	<string>${FIREBASE_GCM_SENDER_ID}</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>${FIREBASE_BUNDLE_ID}</string>
	<key>PROJECT_ID</key>
	<string>${FIREBASE_PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${FIREBASE_STORAGE_BUCKET}</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>IS_APPINVITE_ENABLED</key>
	<true/>
	<key>IS_GCM_ENABLED</key>
	<true/>
	<key>IS_SIGNIN_ENABLED</key>
	<true/>
	<key>GOOGLE_APP_ID</key>
	<string>${FIREBASE_GOOGLE_APP_ID}</string>
</dict>
</plist>
PLIST

echo "GoogleService-Info.plist written to ${PLIST_PATH}"
