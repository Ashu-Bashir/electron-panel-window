var isMac = process.platform === 'darwin';
var NativeExtension = isMac ? require('bindings')('NativeExtension') : undefined;

var panelWindows = new WeakMap();

module.exports = {
  makeKeyWindow: function(window) {
    if (!isMac) return;
    return NativeExtension.MakeKeyWindow(window.getNativeWindowHandle());
  },
  makePanel: function(window) {
    if (!isMac) return;
    
    this._setupDevToolsProtection(window);
    
    panelWindows.set(window, true);
    
    return NativeExtension.MakePanel(window.getNativeWindowHandle());
  },
  
  makeWindow: function(window) {
    if (!isMac) return;
    
    panelWindows.delete(window);
    
    return NativeExtension.MakeWindow(window.getNativeWindowHandle());
  },
  
  _setupDevToolsProtection: function(window) {
    if (window._panelDevToolsProtected) return;
    window._panelDevToolsProtected = true;
    
    const originalOpenDevTools = window.webContents.openDevTools.bind(window.webContents);
    
    window.webContents.openDevTools = (options) => {
      if (panelWindows.has(window)) {
        NativeExtension.MakeWindow(window.getNativeWindowHandle());
        
        const result = originalOpenDevTools(options);
        
        this._monitorDevToolsClose(window);
        
        return result;
      }
      
      return originalOpenDevTools(options);
    };
    
    window.on('closed', () => {
      panelWindows.delete(window);
    });
  },
  
  _monitorDevToolsClose: function(window) {
    const checkDevTools = () => {
      if (!panelWindows.has(window) || window.isDestroyed()) {
        return;
      }
      
      if (!window.webContents.isDevToolsOpened()) {
        setTimeout(() => {
          if (panelWindows.has(window) && !window.isDestroyed()) {
            NativeExtension.MakePanel(window.getNativeWindowHandle());
          }
        }, 100);
      } else {
        setTimeout(checkDevTools, 1000);
      }
    };
    
    setTimeout(checkDevTools, 500);
  },
  
  isPanel: function(window) {
    return panelWindows.has(window);
  }
}