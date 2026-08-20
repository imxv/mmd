#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_path="${project_dir}/dist/MMD.app"
contents_path="${app_path}/Contents"
macos_path="${contents_path}/MacOS"
resources_path="${contents_path}/Resources"

build_arch() {
  local arch="$1"
  swift build --package-path "${project_dir}" -c release --arch "${arch}" >/dev/null
  swift build --package-path "${project_dir}" -c release --arch "${arch}" --show-bin-path
}

arm64_bin_path="$(build_arch arm64)"

rm -rf "${app_path}"
mkdir -p "${macos_path}" "${resources_path}"
cp "${project_dir}/Resources/Info.plist" "${contents_path}/Info.plist"
cp "${project_dir}/.build/checkouts/swift-markdown/LICENSE.txt" "${resources_path}/Swift-Markdown-License.txt"
cp "${project_dir}/.build/checkouts/swift-cmark/COPYING" "${resources_path}/Swift-CMark-License.txt"

if [[ "${MMD_UNIVERSAL:-0}" == "1" ]]; then
  x86_bin_path="$(build_arch x86_64)"
  lipo -create \
    "${arm64_bin_path}/MMD" \
    "${x86_bin_path}/MMD" \
    -output "${macos_path}/MMD"
else
  cp "${arm64_bin_path}/MMD" "${macos_path}/MMD"
fi

strip -x "${macos_path}/MMD"
chmod 755 "${macos_path}/MMD"
codesign --force --sign - --timestamp=none "${app_path}" >/dev/null

size_bytes="$(du -sk "${app_path}" | awk '{print $1 * 1024}')"
size_mb="$(awk -v bytes="${size_bytes}" 'BEGIN { printf "%.2f", bytes / 1024 / 1024 }')"

echo "Built ${app_path}"
echo "App bundle size: ${size_mb} MB (${size_bytes} bytes)"
