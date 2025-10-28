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

// Override dealloc to safely clean up without calling [super dealloc]
- (void)dealloc {
  NSLog(@"PROPanel dealloc called");
}

// Forward any unknown method calls to prevent crashes
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
  NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
  if (!signature) {
    // Create appropriate signatures based on common return types
    NSString *selectorName = NSStringFromSelector(aSelector);
    
    // Methods that return integers/display IDs
    if ([selectorName containsString:@"displayID"] || 
        [selectorName containsString:@"DisplayID"]) {
      // unsigned int return type: I@:
      signature = [NSMethodSignature signatureWithObjCTypes:"I@:"];
    }
    // Methods that return BOOL
    else if ([selectorName hasPrefix:@"is"] || 
             [selectorName hasPrefix:@"has"] ||
             [selectorName hasPrefix:@"can"] ||
             [selectorName hasPrefix:@"should"] ||
             [selectorName containsString:@"Enabled"]) {
      // BOOL return type: c@:
      signature = [NSMethodSignature signatureWithObjCTypes:"c@:"];
    }
    // Methods that return objects/arrays
    else if ([selectorName containsString:@"touchBar"] ||
             [selectorName containsString:@"TouchBar"]) {
      // id return type: @@:
      signature = [NSMethodSignature signatureWithObjCTypes:"@@:"];
    }
    // Default: void return
    else {
      signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
    }
  }
  return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
  NSString *selectorName = NSStringFromSelector([anInvocation selector]);
  
  // Set appropriate return values for different method types
  const char *returnType = [[anInvocation methodSignature] methodReturnType];
  
  if (strcmp(returnType, "c") == 0) {
    // BOOL return - return NO
    BOOL returnValue = NO;
    [anInvocation setReturnValue:&returnValue];
  } else if (strcmp(returnType, "I") == 0 || strcmp(returnType, "i") == 0) {
    // Integer return - return 0
    NSUInteger returnValue = 0;
    [anInvocation setReturnValue:&returnValue];
  } else if (strcmp(returnType, "@") == 0) {
    // Object return - return nil
    id returnValue = nil;
    [anInvocation setReturnValue:&returnValue];
  }
  // For void returns, no need to set anything
}

// Override respondsToSelector to claim we can handle any selector
- (BOOL)respondsToSelector:(SEL)aSelector {
  BOOL responds = [super respondsToSelector:aSelector];
  if (!responds) {
    // Claim we can handle it, then forward to forwardInvocation
    return YES;
  }
  return responds;
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
