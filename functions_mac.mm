#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/objc-runtime.h>
#import <objc/runtime.h>
#include "functions.h"

// Key for storing swizzled state - moved up here for better organization

// Instead of class swapping, we'll use method swizzling to safely override behavior
@interface NSWindow (PanelAdditions)
- (NSWindowStyleMask)panel_styleMask;
- (NSWindowCollectionBehavior)panel_collectionBehavior;
- (BOOL)panel_isFloatingPanel;
- (NSWindowLevel)panel_level;
- (BOOL)panel_canBecomeKeyWindow;
- (BOOL)panel_canBecomeMainWindow;
- (BOOL)panel_needsPanelToBecomeKey;
- (BOOL)panel_acceptsFirstResponder;
@end

@implementation NSWindow (PanelAdditions)
- (NSWindowStyleMask)panel_styleMask {
  return NSWindowStyleMaskTexturedBackground | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView | NSWindowStyleMaskNonactivatingPanel;
}
- (NSWindowCollectionBehavior)panel_collectionBehavior {
  return NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
}
- (BOOL)panel_isFloatingPanel {
  return YES;
}
- (NSWindowLevel)panel_level {
  return NSFloatingWindowLevel;
}
- (BOOL)panel_canBecomeKeyWindow {
  return YES;
}
- (BOOL)panel_canBecomeMainWindow {
  return YES;
}
- (BOOL)panel_needsPanelToBecomeKey {
  return YES;
}
- (BOOL)panel_acceptsFirstResponder {
  return YES;
}
@end

// We no longer need the PROPanel class since we're using method swizzling
// This is much safer than runtime class swapping

// Helper function to swizzle methods safely
void swizzleMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
  Method originalMethod = class_getInstanceMethod(cls, originalSelector);
  Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
  
  if (!originalMethod || !swizzledMethod) {
    NSLog(@"Failed to swizzle method %@ on class %@", NSStringFromSelector(originalSelector), NSStringFromClass(cls));
    return;
  }
  
  BOOL didAddMethod = class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
  
  if (didAddMethod) {
    class_replaceMethod(cls, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
  } else {
    method_exchangeImplementations(originalMethod, swizzledMethod);
  }
}

// Key for storing swizzled state
static const void *kPanelSwizzledKey = &kPanelSwizzledKey;

NAN_METHOD(MakePanel) {
  v8::Local<v8::Object> handleBuffer = info[0].As<v8::Object>();
  v8::Isolate* isolate = info.GetIsolate();
  v8::HandleScope scope(isolate);

  char* buffer = node::Buffer::Data(handleBuffer);
  NSView* mainContentView = *reinterpret_cast<NSView**>(buffer);

  if (!mainContentView)
      return info.GetReturnValue().Set(false);

  NSWindow *nswindow = [mainContentView window];
  
  // Check if already swizzled
  id swizzled = objc_getAssociatedObject(nswindow, kPanelSwizzledKey);
  if (swizzled) {
    NSLog(@"MakePanel: Window %p already converted to panel", nswindow);
    return info.GetReturnValue().Set(true);
  }
  
  NSLog(@"MakePanel: Converting window %p to panel using method swizzling", nswindow);

  nswindow.titlebarAppearsTransparent = true;
  nswindow.titleVisibility = (NSWindowTitleVisibility)1;

  // Use method swizzling instead of class swapping - much safer
  Class windowClass = [nswindow class];
  
  // Swizzle the methods to panel behavior
  swizzleMethod(windowClass, @selector(styleMask), @selector(panel_styleMask));
  swizzleMethod(windowClass, @selector(collectionBehavior), @selector(panel_collectionBehavior));
  swizzleMethod(windowClass, @selector(isFloatingPanel), @selector(panel_isFloatingPanel));
  swizzleMethod(windowClass, @selector(level), @selector(panel_level));
  swizzleMethod(windowClass, @selector(canBecomeKeyWindow), @selector(panel_canBecomeKeyWindow));
  swizzleMethod(windowClass, @selector(canBecomeMainWindow), @selector(panel_canBecomeMainWindow));
  swizzleMethod(windowClass, @selector(needsPanelToBecomeKey), @selector(panel_needsPanelToBecomeKey));
  swizzleMethod(windowClass, @selector(acceptsFirstResponder), @selector(panel_acceptsFirstResponder));
  
  // Mark as swizzled
  objc_setAssociatedObject(nswindow, kPanelSwizzledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  
  NSLog(@"MakePanel: Successfully swizzled window %p methods", nswindow);

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

  // Check if swizzled
  id swizzled = objc_getAssociatedObject(newWindow, kPanelSwizzledKey);
  if (!swizzled) {
    NSLog(@"MakeWindow: Window %p was not swizzled", newWindow);
    return info.GetReturnValue().Set(true);
  }

  NSLog(@"MakeWindow: Restoring window %p from panel behavior", newWindow);

  Class windowClass = [newWindow class];
  
  // Unswizzle the methods back to original behavior
  swizzleMethod(windowClass, @selector(styleMask), @selector(panel_styleMask));
  swizzleMethod(windowClass, @selector(collectionBehavior), @selector(panel_collectionBehavior));
  swizzleMethod(windowClass, @selector(isFloatingPanel), @selector(panel_isFloatingPanel));
  swizzleMethod(windowClass, @selector(level), @selector(panel_level));
  swizzleMethod(windowClass, @selector(canBecomeKeyWindow), @selector(panel_canBecomeKeyWindow));
  swizzleMethod(windowClass, @selector(canBecomeMainWindow), @selector(panel_canBecomeMainWindow));
  swizzleMethod(windowClass, @selector(needsPanelToBecomeKey), @selector(panel_needsPanelToBecomeKey));
  swizzleMethod(windowClass, @selector(acceptsFirstResponder), @selector(panel_acceptsFirstResponder));
  
  // Clear the swizzled marker
  objc_setAssociatedObject(newWindow, kPanelSwizzledKey, nil, OBJC_ASSOCIATION_ASSIGN);
  
  NSLog(@"MakeWindow: Successfully restored window %p methods", newWindow);

  return info.GetReturnValue().Set(true);
}
