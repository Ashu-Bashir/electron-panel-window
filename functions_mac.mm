#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/objc-runtime.h>
#include "functions.h"

@interface PROPanel : NSWindow
@end

@implementation PROPanel
- (NSWindowStyleMask)styleMask {
  return NSWindowStyleMaskTexturedBackground | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView | NSWindowStyleMaskNonactivatingPanel;
}
- (NSWindowCollectionBehavior)collectionBehavior {
  return NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
}
- (BOOL)isFloatingPanel {
  return YES;
}
- (NSWindowLevel)level {
  return NSFloatingWindowLevel;
}
- (BOOL)canBecomeKeyWindow {
  return YES;
}
- (BOOL)canBecomeMainWindow {
  return YES;
}
- (BOOL)needsPanelToBecomeKey {
  return YES;
}
- (BOOL)acceptsFirstResponder {
  return YES;
}
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context {
  // macOS Big Sur attempts to remove an observer for the NSTitlebarView that doesn't exist.
  // This is due to us changing the class from NSWindow -> NSPanel at runtime, it's possible
  // there is assumed setup that doesn't happen. Details of the exception this is avoiding are
  // here: https://github.com/goabstract/electron-panel-window/issues/6
  if ([keyPath isEqualToString:@"_titlebarBackdropGroupName"]) {
    // NSLog(@"removeObserver ignored");
    return;
  }

  if (context) {
    [super removeObserver:observer forKeyPath:keyPath context:context];
  } else {
    [super removeObserver:observer forKeyPath:keyPath];
  }
}
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
  [self removeObserver:observer forKeyPath:keyPath context:NULL];
}
- (void)disableHeadlessMode {
  // Electron 36+ compatibility - no-op for panel windows
  // Headless mode is typically used for testing/automation, 
  // which doesn't apply to panel windows
}
- (void)cleanup {
  // Prevent crash when Electron tries to call cleanup on panel windows
  // This method is expected by newer versions of Electron but doesn't exist
  // on NSPanel, so we provide a no-op implementation
  NSLog(@"PROPanel cleanup called - no-op to prevent crash");
}

// Additional cleanup methods that Electron might expect
- (void)cleanupWebContents {
  // No-op to prevent crashes
  NSLog(@"PROPanel cleanupWebContents called - no-op");
}

- (void)cleanupBrowserWindow {
  // No-op to prevent crashes  
  NSLog(@"PROPanel cleanupBrowserWindow called - no-op");
}

- (void)destroy {
  // Another method Electron might call during destruction
  NSLog(@"PROPanel destroy called - no-op");
}

- (void)_destroy {
  // Private destroy method Electron might call
  NSLog(@"PROPanel _destroy called - no-op");
}

// Forward any unknown method calls to prevent crashes
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
  NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
  if (!signature) {
    // Create a dummy signature for any missing selector
    signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
  }
  return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
  // Log the missing method and do nothing
  NSLog(@"PROPanel: Missing method %@ called - ignoring to prevent crash", NSStringFromSelector([anInvocation selector]));
}
@end

Class electronWindowClass;

NAN_METHOD(MakePanel) {
  v8::Local<v8::Object> handleBuffer = info[0].As<v8::Object>();
  v8::Isolate* isolate = info.GetIsolate();
  v8::HandleScope scope(isolate);

  char* buffer = node::Buffer::Data(handleBuffer);
  NSView* mainContentView = *reinterpret_cast<NSView**>(buffer);

  if (!mainContentView)
      return info.GetReturnValue().Set(false);

  electronWindowClass = [mainContentView.window class];

//   NSLog(@"class of main window before = %@", object_getClass(mainContentView.window));

  NSWindow *nswindow = [mainContentView window];
  nswindow.titlebarAppearsTransparent = true;
  nswindow.titleVisibility = (NSWindowTitleVisibility)1;

//   NSLog(@"stylemask = %ld", mainContentView.window.styleMask);

  // Convert the NSWindow class to PROPanel
  object_setClass(mainContentView.window, [PROPanel class]);

//   NSLog(@"class of main window after = %@", object_getClass(mainContentView.window));
//   NSLog(@"stylemask after = %ld", mainContentView.window.styleMask);



  return info.GetReturnValue().Set(true);
}

NAN_METHOD(MakeKeyWindow) {
  v8::Local<v8::Object> handleBuffer = info[0].As<v8::Object>();
  v8::Isolate* isolate = info.GetIsolate();
  v8::HandleScope scope(isolate);

  char* buffer = node::Buffer::Data(handleBuffer);
  NSView* mainContentView = *reinterpret_cast<NSView**>(buffer);

  if (!mainContentView)
      return info.GetReturnValue().Set(false);

  [mainContentView.window makeKeyWindow];
  [mainContentView.window makeMainWindow];
  return info.GetReturnValue().Set(true);
}


NAN_METHOD(MakeWindow) {

  v8::Local<v8::Object> handleBuffer = info[0].As<v8::Object>();
  v8::Isolate* isolate = info.GetIsolate();
  v8::HandleScope scope(isolate);

  char* buffer = node::Buffer::Data(handleBuffer);
  NSView* mainContentView = *reinterpret_cast<NSView**>(buffer);

    if (!mainContentView)
      return info.GetReturnValue().Set(false);

  NSWindow* newWindow = mainContentView.window;

  // Convert the NSPanel class to whatever it was before
  object_setClass(newWindow, electronWindowClass);

  return info.GetReturnValue().Set(true);
}
