# 1.0.20
- fix build failure on machines with older Xcode Command Line Tools: Electron 43+'s V8 headers require C++20's `<source_location>`, which is missing from older libc++ SDKs (`fatal error: 'source_location' file not found`). Added a fallback polyfill (`shims/source_location`) wired in via `-idirafter` so it's only used when the real header is unavailable.


# 4.1.0
- fixes mac build
- update electron target to v21.3.0


# 4.0.0
- **BREAKING**: build using electron target v21.2.3
- updated dependencies


# 3.2.1
- initial release