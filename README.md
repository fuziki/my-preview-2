# my-preview

A simple JPEG photo browser for iOS.

Browse JPEG files in a folder, view Exif metadata, and save photos to your iOS photo library.

## Features

- Pick a folder and list JPEG files
- Full-screen viewer with pinch-to-zoom and double-tap zoom
- Exif metadata display (ISO, focal length, exposure, f-number, shutter speed)
- Save photos to the iOS photo library without re-encoding

## Requirements

- iOS 26+
- Xcode 26+

## Setup

1. Copy `Config/Local.xcconfig.template` to `Config/Local.xcconfig`
2. Fill in your `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER`
3. Open `my-preview-2.xcodeproj` and run
