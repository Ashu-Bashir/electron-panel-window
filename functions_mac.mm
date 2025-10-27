#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/objc-runtime.h>
#import <objc/runtime.h>
#include "functions.h"

// Associated object key for storing original window class per window
static const void *kOriginalWindowClassKey = &kOriginalWindowClassKey;

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

// Additional Electron window methods that might be called
- (void)closeWebContents {
  NSLog(@"PROPanel closeWebContents called - no-op");
}

- (void)destroyWebContents {
  NSLog(@"PROPanel destroyWebContents called - no-op");
}

- (void)_closeWebContents {
  NSLog(@"PROPanel _closeWebContents called - no-op");
}

- (void)handleWindowClose {
  NSLog(@"PROPanel handleWindowClose called - no-op");
}

- (void)willClose {
  NSLog(@"PROPanel willClose called - no-op");
}

- (void)_willClose {
  NSLog(@"PROPanel _willClose called - no-op");
}

// Override dealloc to log and safely clean up - ARC safe version
- (void)dealloc {
  NSLog(@"PROPanel dealloc called");
#if !__has_feature(objc_arc)
  [super dealloc];
#endif
}

// Forward any unknown method calls to prevent crashes - safer version
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
  NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
  if (signature) return signature;

  // Provide void-returning signature for our known no-arg methods:
  if (sel_isEqual(aSelector, @selector(cleanup)) ||
      sel_isEqual(aSelector, @selector(cleanupWebContents)) ||
      sel_isEqual(aSelector, @selector(cleanupBrowserWindow)) ||
      sel_isEqual(aSelector, @selector(destroy)) ||
      sel_isEqual(aSelector, @selector(_destroy)) ||
      sel_isEqual(aSelector, @selector(closeWebContents)) ||
      sel_isEqual(aSelector, @selector(destroyWebContents)) ||
      sel_isEqual(aSelector, @selector(_closeWebContents)) ||
      sel_isEqual(aSelector, @selector(handleWindowClose)) ||
      sel_isEqual(aSelector, @selector(willClose)) ||
      sel_isEqual(aSelector, @selector(_willClose)) ||
      sel_isEqual(aSelector, @selector(disableHeadlessMode))) {
    return [NSMethodSignature signatureWithObjCTypes:"v@:"];
  }

  return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
  // Log the missing method and do nothing
  NSLog(@"PROPanel: Missing method %@ called - ignoring to prevent crash", NSStringFromSelector([anInvocation selector]));
  // Don't call anything - just return safely
}

// Override respondsToSelector - only claim we can handle specific selectors
- (BOOL)respondsToSelector:(SEL)aSelector {
  // Only claim to respond for selectors we actually expect to handle/forward
  if (sel_isEqual(aSelector, @selector(cleanup)) ||
      sel_isEqual(aSelector, @selector(cleanupWebContents)) ||
      sel_isEqual(aSelector, @selector(cleanupBrowserWindow)) ||
      sel_isEqual(aSelector, @selector(destroy)) ||
      sel_isEqual(aSelector, @selector(_destroy)) ||
      sel_isEqual(aSelector, @selector(closeWebContents)) ||
      sel_isEqual(aSelector, @selector(destroyWebContents)) ||
      sel_isEqual(aSelector, @selector(_closeWebContents)) ||
      sel_isEqual(aSelector, @selector(handleWindowClose)) ||
      sel_isEqual(aSelector, @selector(willClose)) ||
      sel_isEqual(aSelector, @selector(_willClose)) ||
      sel_isEqual(aSelector, @selector(disableHeadlessMode))) {
    return YES;
  }
  return [super respondsToSelector:aSelector];
}
@end

NAN_METHOD(MakePanel) {
  v8::Local<v8::Object> handleBuffer = info[0].As<v8::Object>();
  v8::Isolate* isolate = info.GetIsolate();
  v8::HandleScope scope(isolate);

  char* buffer = node::Buffer::Data(handleBuffer);
  NSView* mainContentView = *reinterpret_cast<NSView**>(buffer);

  if (!mainContentView)
      return info.GetReturnValue().Set(false);

  NSWindow *nswindow = [mainContentView window];
  
  // Store the original class per window using associated objects
  Class originalClass = object_getClass(nswindow);
  objc_setAssociatedObject(nswindow, kOriginalWindowClassKey, (__bridge id)originalClass, OBJC_ASSOCIATION_ASSIGN);
  
  NSLog(@"MakePanel: Storing original class %@ for window %p", NSStringFromClass(originalClass), nswindow);

  nswindow.titlebarAppearsTransparent = true;
  nswindow.titleVisibility = (NSWindowTitleVisibility)1;

  // Convert the NSWindow class to PROPanel
  object_setClass(nswindow, [PROPanel class]);
  
  NSLog(@"MakePanel: Changed window %p class to PROPanel", nswindow);

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

  // Restore the original class from associated object
  id stored = objc_getAssociatedObject(newWindow, kOriginalWindowClassKey);
  if (stored) {
    Class originalClass = (__bridge Class)stored;
    NSLog(@"MakeWindow: Restoring window %p to original class %@", newWindow, NSStringFromClass(originalClass));
    object_setClass(newWindow, originalClass);
    // Clear the stored association
    objc_setAssociatedObject(newWindow, kOriginalWindowClassKey, nil, OBJC_ASSOCIATION_ASSIGN);
  } else {
    NSLog(@"MakeWindow: Warning - no original class stored for window %p", newWindow);
  }

  return info.GetReturnValue().Set(true);
}
