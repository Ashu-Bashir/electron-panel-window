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

// --- Safe swizzle helper ---
void SafeCleanupSwizzle(Class targetClass) {
  SEL cleanupSel = @selector(cleanup);
  Method existing = class_getInstanceMethod(targetClass, cleanupSel);

  if (!existing) {
    IMP noopImp = imp_implementationWithBlock(^(id _self) {
      NSLog(@"Safe cleanup called - no-op for %@", _self);
    });
    class_addMethod(targetClass, cleanupSel, noopImp, "v@:");
  }

  SEL cleanupWebContentsSel = @selector(cleanupWebContents);
  if (!class_getInstanceMethod(targetClass, cleanupWebContentsSel)) {
    IMP noopImp2 = imp_implementationWithBlock(^(id _self) {
      NSLog(@"Safe cleanupWebContents called - no-op for %@", _self);
    });
    class_addMethod(targetClass, cleanupWebContentsSel, noopImp2, "v@:");
  }

  SEL destroySel = @selector(destroy);
  if (!class_getInstanceMethod(targetClass, destroySel)) {
    IMP noopImp3 = imp_implementationWithBlock(^(id _self) {
      NSLog(@"Safe destroy called - no-op for %@", _self);
    });
    class_addMethod(targetClass, destroySel, noopImp3, "v@:");
  }
}


Class electronWindowClass;

NAN_METHOD(MakePanel) {
  v8::Local<v8::Object> handleBuffer = info[0].As<v8::Object>();
  v8::Isolate* isolate = info.GetIsolate();
  v8::HandleScope scope(isolate);

  char* buffer = node::Buffer::Data(handleBuffer);
  NSView* mainContentView = *reinterpret_cast<NSView**>(buffer);

  if (!mainContentView)
      return info.GetReturnValue().Set(false);

  NSWindow *nswindow = [mainContentView window];
  electronWindowClass = [nswindow class];

  // Dynamically create a subclass only once
  static Class DynamicPanelClass = Nil;
  if (!DynamicPanelClass) {
    NSString *subclassName = [NSString stringWithFormat:@"%@_PROPanel", NSStringFromClass(electronWindowClass)];
    DynamicPanelClass = objc_allocateClassPair(electronWindowClass, [subclassName UTF8String], 0);

    // Copy methods from PROPanel to new subclass
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList([PROPanel class], &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
      class_addMethod(DynamicPanelClass,
                      method_getName(methods[i]),
                      method_getImplementation(methods[i]),
                      method_getTypeEncoding(methods[i]));
    }
    free(methods);
    objc_registerClassPair(DynamicPanelClass);
  }

  // Assign the subclass safely
  object_setClass(nswindow, DynamicPanelClass);

  // Apply panel appearance tweaks
  nswindow.titlebarAppearsTransparent = YES;
  nswindow.titleVisibility = (NSWindowTitleVisibility)1;
  nswindow.level = NSFloatingWindowLevel;
  nswindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;

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

NAN_METHOD(Destroy) {
  v8::Local<v8::Object> browserWindow = info[0].As<v8::Object>();
  if (browserWindow.IsEmpty() || !browserWindow->IsObject()) {
    Nan::ThrowTypeError("Argument must be a BrowserWindow object");
    return;
  }

  v8::Local<v8::Value> handleValue = Nan::Get(browserWindow, Nan::New("getNativeWindowHandle").ToLocalChecked()).ToLocalChecked();
  if (handleValue.IsEmpty() || !handleValue->IsFunction()) {
    Nan::ThrowTypeError("Could not get getNativeWindowHandle function");
    return;
  }

  v8::Local<v8::Function> getNativeWindowHandle = handleValue.As<v8::Function>();
  v8::Local<v8::Value> argv[] = {};
  v8::Local<v8::Value> result = Nan::Call(getNativeWindowHandle, browserWindow, 0, argv).ToLocalChecked();

  if (result.IsEmpty() || !result->IsObject()) {
    Nan::ThrowTypeError("Could not get native window handle");
    return;
  }

  v8::Local<v8::Object> handleBuffer = result.As<v8::Object>();
  void* handle = node::Buffer::Data(handleBuffer);
  NSWindow* window = (NSWindow*)handle;

  if (window) {
    [window close];
  }
}
