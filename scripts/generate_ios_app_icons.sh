#!/bin/sh
set -eu

SOURCE_ICON="assets/icons/ios_app_icon_source.png"
TARGET_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"
LAUNCH_DIR="ios/Runner/Assets.xcassets/LaunchImage.imageset"

if [ ! -f "$SOURCE_ICON" ]; then
  echo "Missing source icon: $SOURCE_ICON" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

resize_icon() {
  pixels="$1"
  filename="$2"
  sips -z "$pixels" "$pixels" "$SOURCE_ICON" --out "$TARGET_DIR/$filename" >/dev/null
}

resize_icon 20 "Icon-App-20x20@1x.png"
resize_icon 40 "Icon-App-20x20@2x.png"
resize_icon 60 "Icon-App-20x20@3x.png"
resize_icon 29 "Icon-App-29x29@1x.png"
resize_icon 58 "Icon-App-29x29@2x.png"
resize_icon 87 "Icon-App-29x29@3x.png"
resize_icon 40 "Icon-App-40x40@1x.png"
resize_icon 80 "Icon-App-40x40@2x.png"
resize_icon 120 "Icon-App-40x40@3x.png"
resize_icon 50 "Icon-App-50x50@1x.png"
resize_icon 100 "Icon-App-50x50@2x.png"
resize_icon 57 "Icon-App-57x57@1x.png"
resize_icon 114 "Icon-App-57x57@2x.png"
resize_icon 120 "Icon-App-60x60@2x.png"
resize_icon 180 "Icon-App-60x60@3x.png"
resize_icon 72 "Icon-App-72x72@1x.png"
resize_icon 144 "Icon-App-72x72@2x.png"
resize_icon 76 "Icon-App-76x76@1x.png"
resize_icon 152 "Icon-App-76x76@2x.png"
resize_icon 167 "Icon-App-83.5x83.5@2x.png"
resize_icon 1024 "Icon-App-1024x1024@1x.png"

cat >"$TARGET_DIR/Contents.json" <<'EOF'
{
  "images" : [
    { "size" : "20x20", "idiom" : "iphone", "filename" : "Icon-App-20x20@2x.png", "scale" : "2x" },
    { "size" : "20x20", "idiom" : "iphone", "filename" : "Icon-App-20x20@3x.png", "scale" : "3x" },
    { "size" : "29x29", "idiom" : "iphone", "filename" : "Icon-App-29x29@1x.png", "scale" : "1x" },
    { "size" : "29x29", "idiom" : "iphone", "filename" : "Icon-App-29x29@2x.png", "scale" : "2x" },
    { "size" : "29x29", "idiom" : "iphone", "filename" : "Icon-App-29x29@3x.png", "scale" : "3x" },
    { "size" : "40x40", "idiom" : "iphone", "filename" : "Icon-App-40x40@2x.png", "scale" : "2x" },
    { "size" : "40x40", "idiom" : "iphone", "filename" : "Icon-App-40x40@3x.png", "scale" : "3x" },
    { "size" : "57x57", "idiom" : "iphone", "filename" : "Icon-App-57x57@1x.png", "scale" : "1x" },
    { "size" : "57x57", "idiom" : "iphone", "filename" : "Icon-App-57x57@2x.png", "scale" : "2x" },
    { "size" : "60x60", "idiom" : "iphone", "filename" : "Icon-App-60x60@2x.png", "scale" : "2x" },
    { "size" : "60x60", "idiom" : "iphone", "filename" : "Icon-App-60x60@3x.png", "scale" : "3x" },
    { "size" : "20x20", "idiom" : "ipad", "filename" : "Icon-App-20x20@1x.png", "scale" : "1x" },
    { "size" : "20x20", "idiom" : "ipad", "filename" : "Icon-App-20x20@2x.png", "scale" : "2x" },
    { "size" : "29x29", "idiom" : "ipad", "filename" : "Icon-App-29x29@1x.png", "scale" : "1x" },
    { "size" : "29x29", "idiom" : "ipad", "filename" : "Icon-App-29x29@2x.png", "scale" : "2x" },
    { "size" : "40x40", "idiom" : "ipad", "filename" : "Icon-App-40x40@1x.png", "scale" : "1x" },
    { "size" : "40x40", "idiom" : "ipad", "filename" : "Icon-App-40x40@2x.png", "scale" : "2x" },
    { "size" : "50x50", "idiom" : "ipad", "filename" : "Icon-App-50x50@1x.png", "scale" : "1x" },
    { "size" : "50x50", "idiom" : "ipad", "filename" : "Icon-App-50x50@2x.png", "scale" : "2x" },
    { "size" : "72x72", "idiom" : "ipad", "filename" : "Icon-App-72x72@1x.png", "scale" : "1x" },
    { "size" : "72x72", "idiom" : "ipad", "filename" : "Icon-App-72x72@2x.png", "scale" : "2x" },
    { "size" : "76x76", "idiom" : "ipad", "filename" : "Icon-App-76x76@1x.png", "scale" : "1x" },
    { "size" : "76x76", "idiom" : "ipad", "filename" : "Icon-App-76x76@2x.png", "scale" : "2x" },
    { "size" : "83.5x83.5", "idiom" : "ipad", "filename" : "Icon-App-83.5x83.5@2x.png", "scale" : "2x" },
    { "size" : "1024x1024", "idiom" : "ios-marketing", "filename" : "Icon-App-1024x1024@1x.png", "scale" : "1x" }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
EOF

# Generate a non-placeholder launch image to satisfy App Store validation.
mkdir -p "$LAUNCH_DIR"

resize_launch_image() {
  pixels="$1"
  filename="$2"
  sips -z "$pixels" "$pixels" "$SOURCE_ICON" --out "$LAUNCH_DIR/$filename" >/dev/null
}

resize_launch_image 180 "LaunchImage.png"
resize_launch_image 360 "LaunchImage@2x.png"
resize_launch_image 540 "LaunchImage@3x.png"

cat >"$LAUNCH_DIR/Contents.json" <<'EOF'
{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "LaunchImage.png",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "filename" : "LaunchImage@2x.png",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "filename" : "LaunchImage@3x.png",
      "scale" : "3x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
EOF
