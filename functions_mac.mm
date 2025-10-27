#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/objc-runtime.h>
#import <objc/runtime.h>
#include "functions.h"

// Using simple property setting approach - much safer than method swizzling or class swapping

// Simple and safe approach - just set window properties directly
// Key for storing original properties
static const void *kOriginalPropertiesKey = &kOriginalPropertiesKey;

@interface WindowProperties : NSObject
@property (nonatomic) NSWindowStyleMask originalStyleMask;
@property (nonatomic) NSWindowCollectionBehavior originalCollectionBehavior;
@property (nonatomic) NSWindowLevel originalLevel;
@end

@implementation WindowProperties
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
  
  // Check if already converted
  id stored = objc_getAssociatedObject(nswindow, kOriginalPropertiesKey);
  if (stored) {
    NSLog(@"MakePanel: Window %p already converted to panel", nswindow);
    return info.GetReturnValue().Set(true);
  }
  
  NSLog(@"MakePanel: Converting window %p to panel by setting properties", nswindow);

  // Store original properties
  WindowProperties *originalProps = [[WindowProperties alloc] init];
  originalProps.originalStyleMask = nswindow.styleMask;
  originalProps.originalCollectionBehavior = nswindow.collectionBehavior;
  originalProps.originalLevel = nswindow.level;
  
  objc_setAssociatedObject(nswindow, kOriginalPropertiesKey, originalProps, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  // Set panel properties directly - much safer than method swizzling
  nswindow.titlebarAppearsTransparent = true;
  nswindow.titleVisibility = (NSWindowTitleVisibility)1;
  
  // Set panel-like behavior
  nswindow.styleMask = NSWindowStyleMaskTexturedBackground | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView | NSWindowStyleMaskNonactivatingPanel;
  nswindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
  nswindow.level = NSFloatingWindowLevel;
  
  NSLog(@"MakePanel: Successfully converted window %p to panel", nswindow);

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

  // Check if we have stored properties
  WindowProperties *originalProps = objc_getAssociatedObject(newWindow, kOriginalPropertiesKey);
  if (!originalProps) {
    NSLog(@"MakeWindow: Window %p was not converted to panel", newWindow);
    return info.GetReturnValue().Set(true);
  }

  NSLog(@"MakeWindow: Restoring window %p from panel to original window behavior", newWindow);

  // Restore original properties
  newWindow.styleMask = originalProps.originalStyleMask;
  newWindow.collectionBehavior = originalProps.originalCollectionBehavior;
  newWindow.level = originalProps.originalLevel;
  
  // Clear the stored properties
  objc_setAssociatedObject(newWindow, kOriginalPropertiesKey, nil, OBJC_ASSOCIATION_ASSIGN);
  
  NSLog(@"MakeWindow: Successfully restored window %p to original behavior", newWindow);

  return info.GetReturnValue().Set(true);
}
