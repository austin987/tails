window.__HookObjects = function() {
  if (typeof(window.__tb_hooks_ran) === "boolean") {
      return false;
  }

  /* For reference/debugging only:
  if(false && window.__tb_set_uagent===true) {
      var tmp_oscpu = window.__tb_oscpu;
      var tmp_platform = window.__tb_platform;
      var tmp_productSub = window.__tb_productSub;

      try {
          if(!(window.navigator.__proto__ == null) ||
                  typeof(window.navigator.__defineGetter__) === "function") {
              var cE = window.navigator.cookieEnabled;
              var lang = window.navigator.language;
              var uA = window.navigator.userAgent;
              var v = window.navigator.vendor;
              var vS = window.navigator.vendorSub;
              var jE = window.navigator.javaEnabled;
              var pl = new window.Array();
              var mT = new window.Object();
              //var pl = window.navigator.plugins;
              //var mT = window.navigator.mimeTypes;

              window.navigator.__defineGetter__("appCodeName", function() { return "Mozilla";});
              window.navigator.__defineGetter__("appName", function() { return "Netscape";});
              window.navigator.__defineGetter__("appVersion", function() { return "5.0";});
              window.navigator.__defineGetter__("buildID", function() { return 0;});
              window.navigator.__defineGetter__("cookieEnabled", function() { return cE;});
              window.navigator.__defineGetter__("language", function() { return lang;});
              window.navigator.__defineGetter__("mimeTypes", function() { return mT;});
              window.navigator.__defineGetter__("onLine", function() { return true;});
              window.navigator.__defineGetter__("oscpu", function() { return tmp_oscpu;});
              window.navigator.__defineGetter__("platform", function() { return tmp_platform;});
              window.navigator.__defineGetter__("plugins", function() { return pl;});
              window.navigator.__defineGetter__("product", function() { return "Gecko";});
              window.navigator.__defineGetter__("productSub", function() { return tmp_productSub;});
              window.navigator.__defineGetter__("securityPolicy", function() { return "";});
              window.navigator.__defineGetter__("userAgent", function() { return uA;});
              window.navigator.__defineGetter__("vendor", function() { return v;});
              window.navigator.__defineGetter__("vendorSub", function() { return vS;});
              window.navigator.__defineGetter__("javaEnabled", function() { return jE;});
              window.navigator.__proto__ = null;
          }
      } catch(e) {
      }
  } */


  /* Hrmm.. Is it possible this breaks plugin install or other weird shit
     for non-windows OS's? */
  if(window.__tb_set_uagent===true) {
      var tmp_oscpu = window.__tb_oscpu;
      var tmp_platform = window.__tb_platform;
      var tmp_productSub = window.__tb_productSub;
      var tmp_locale = window.__tb_locale;

      // This is just unreasonable.. Firefox caches 
      // window.navigator.__proto__ between same-origin loads of a document. 
      // So this means when we null it out, we lose most of the navigator 
      // object for subsequent loads. I tried doing the whole-object hooks 
      // like we do for Date, screen, and history, but it seems to behave 
      // like Date upon delete, allowing unmasking for that case. Talk about 
      // rock+hard place. 
      try {
          if(!(window.navigator.__proto__ == null) ||
             typeof(window.navigator.__defineGetter__) === "function") {
              var tmpNav = new window.Object();
              for(var i in window.navigator) {
                  tmpNav[i] = window.navigator[i];
                  
                  // XPCNative objects are special for some reason. So far, 
                  // all we have are "plugins" and mimeTypes, which 
                  // are empty anyways. Disable them.
                  //if(tmpNav[i].toString().indexOf("XPCNative") != -1) {
                  if(i === "plugins" || i === "mimeTypes") {
                      tmpNav[i] = new Array();
                  }
                  (function() { // crazy scope hack to preserve i
                      var holder = i;
                      window.navigator.__defineGetter__(i, function() { return tmpNav[holder];});
                  })();
              }

              if(tmp_locale != false) {
                  window.navigator.__defineGetter__("language", function() { return tmp_locale;});
              }
              window.navigator.__defineGetter__("oscpu", function() { return tmp_oscpu;});
              window.navigator.__defineGetter__("productSub", function() { return tmp_productSub;});
              window.navigator.__defineGetter__("buildID", function() { return 0;});
              window.navigator.__proto__ = null;
          }
      } catch(e) {
      }
  }

  // No pref for this.. Should be mostly harmless..
  if(true) {
      window.__proto__.__defineGetter__("outerWidth", function() { return window.innerWidth;});
      window.__proto__.__defineGetter__("outerHeight", function() { return window.innerHeight;});
      window.__proto__.__defineGetter__("screenX", function() { return 0;});
      window.__proto__.__defineGetter__("screenY", function() { return 0;});
      window.__proto__.__defineGetter__("pageXOffset", function() { return 0;});
      window.__proto__.__defineGetter__("pageYOffset", function() { return 0;});

      // Wrap in anonymous function to protect scr variables just in case.
      (function () {
          // We can't define individual getters/setters for window.screen 
          // for some reason. works in html but not in these hooks.. No idea why

          var scr = new Object();
          var origScr = window.screen;
          scr.__defineGetter__("height", function() { return window.innerHeight; });
          scr.__defineGetter__("width", function() { return window.innerWidth; });

          scr.__defineGetter__("availTop", function() { return 0;});
          scr.__defineGetter__("availLeft", function() { return 0;});

          scr.__defineGetter__("top", function() { return 0;});
          scr.__defineGetter__("left", function() { return 0;});

          scr.__defineGetter__("availHeight", function() { return window.innerHeight;});
          scr.__defineGetter__("availWidth", function() { return window.innerWidth;});

          scr.__defineGetter__("colorDepth", function() { return origScr.colorDepth;});
          scr.__defineGetter__("pixelDepth", function() { return origScr.pixelDepth;});

          scr.__defineGetter__("availTop", function() { return 0;});
          scr.__defineGetter__("availLeft", function() { return 0;});

          window.__defineGetter__("screen", function() { return scr; });
          window.__defineSetter__("screen", function(a) { return; });
          window.__proto__.__defineGetter__("screen", function() { return scr; });

          // Needed for Firefox bug 418983:
          with(window) {
              var screen = scr;
          }

      })();

  }
  

  if(window.__tb_hook_date == true) { // don't feel like indenting this

  /* Timezone fix for http://gemal.dk/browserspy/css.html */
  var reparseDate = function(d, str) {
    /* Rules:
     *   - If they specify a timezone, it is converted to local
     *     time. All getter fucntions then convert properly to
     *     UTC. No mod needed.
     *   - If they specify UTC timezone, then it is converted
     *     to local time. All getter functions then convert back.
     *     No mod needed.
     *   - If they specify NO timezone, it is local time. 
     *     The UTC conversion then reveals the offset. Fix.
     */
    
    /* Step 1: Remove everything inside ()'s (they are "comments") */
    var s = str.toLowerCase();
    var re = new RegExp('\\(.*\\)', "gm");
    s = s.replace(re, "");

    /* Step 2: Look for +/-. If found, do nothing */
    if(s.indexOf("+") == -1 && s.indexOf("-") == -1) {
      /* Step 3: Look for timezone string from
       * http://lxr.mozilla.org/seamonkey/source/js/src/jsdate.c
       */
      if(s.indexOf(" gmt") == -1 && s.indexOf(" ut") == -1 &&
         s.indexOf(" est") == -1 && s.indexOf(" edt") == -1 &&
         s.indexOf(" cst") == -1 && s.indexOf(" cdt") == -1 &&
         s.indexOf(" mst") == -1 && s.indexOf(" mdt") == -1 &&
         s.indexOf(" pst") == -1 && s.indexOf(" pdt")) {
        /* No timezone specified. Adjust. */
        d.setTime(d.getTime()-(d.getTimezoneOffset()*60000));
      }
    } 
  } 
  
  var origDate = window.Date;
  var newDate = function() {
    /* DO NOT make 'd' a member! EvilCode will use it! */
    var d;
    var a = arguments;
    /* apply doesn't seem to work for constructors :( */
    if(arguments.length == 0) d=new origDate();
    if(arguments.length == 1) d=new origDate(a[0]);
    if(arguments.length == 3) d=new origDate(a[0],a[1],a[2]);
    if(arguments.length == 4) d=new origDate(a[0],a[1],a[2],a[3]);
    if(arguments.length == 5) d=new origDate(a[0],a[1],a[2],a[3],a[4]);
    if(arguments.length == 6) d=new origDate(a[0],a[1],a[2],a[3],a[4],a[5]);
    if(arguments.length == 7) d=new origDate(a[0],a[1],a[2],a[3],a[4],a[5],a[6]);
    if(arguments.length > 7) d=new origDate();

    if(arguments.length > 0) {
      if((arguments.length == 1) && typeof(a[0]) == "string") {
        reparseDate(d,a[0]);
      } else if(arguments.length > 1) { 
        /* Numerical value. No timezone given, adjust. */
        d.setTime(d.getTime()-(d.getTimezoneOffset()*60000));
      }
    }

    // XXX: the native valueOf seems to sometimes return toString and 
    // sometimes return getTime depending on context (which we can't detect)
    // It seems as though we can't win here..
    window.Date.prototype.valueOf=function(){return d.getTime()};
    window.Date.prototype.getTime=function(){return d.getTime();} /* UTC already */ 
    window.Date.prototype.getFullYear=function(){return d.getUTCFullYear();}  
    window.Date.prototype.getYear=function() {return d.getYear();}
    window.Date.prototype.getMonth=function(){return d.getUTCMonth();}
    window.Date.prototype.getDate=function() {return d.getUTCDate();}
    window.Date.prototype.getDay=function() {return d.getUTCDay();}
    window.Date.prototype.getHours=function(){return d.getUTCHours();}
    window.Date.prototype.getMinutes=function(){return d.getUTCMinutes();}
    window.Date.prototype.getSeconds=function(){return d.getUTCSeconds();}
    window.Date.prototype.getMilliseconds=function(){return d.getUTCMilliseconds();}
    window.Date.prototype.getTimezoneOffset=function(){return 0;}
 
    window.Date.prototype.setTime = 
       function(x) {return d.setTime(x);}
    window.Date.prototype.setFullYear=function(x){return d.setUTCFullYear(x);}
    window.Date.prototype.setYear=function(x){return d.setYear(x);}
    window.Date.prototype.setMonth=function(x){return d.setUTCMonth(x);}
    window.Date.prototype.setDate=function(x){return d.setUTCDate(x);}
    window.Date.prototype.setDay=function(x){return d.setUTCDay(x);}
    window.Date.prototype.setHours=function(x){return d.setUTCHours(x);}
    window.Date.prototype.setMinutes=function(x){return d.setUTCMinutes(x);}
    window.Date.prototype.setSeconds=function(x){return d.setUTCSeconds(x);}
    window.Date.prototype.setMilliseconds=
       function(x) {return d.setUTCMilliseconds(x);}
 
    window.Date.prototype.getUTCFullYear=function(){return d.getUTCFullYear();}  
    window.Date.prototype.getUTCMonth=function(){return d.getUTCMonth();}
    window.Date.prototype.getUTCDate=function() {return d.getUTCDate();}
    window.Date.prototype.getUTCDay=function() {return d.getUTCDay();}
    window.Date.prototype.getUTCHours=function(){return d.getUTCHours();}
    window.Date.prototype.getUTCMinutes=function(){return d.getUTCMinutes();}
    window.Date.prototype.getUTCSeconds=function(){return d.getUTCSeconds();}
    window.Date.prototype.getUTCMilliseconds=
       function(){return d.getUTCMilliseconds();}
     
    window.Date.prototype.setUTCFullYear=function(x){return d.setUTCFullYear(x);}
    window.Date.prototype.setUTCMonth=function(x){return d.setUTCMonth(x);}
    window.Date.prototype.setUTCDate=function(x){return d.setUTCDate(x);}
    window.Date.prototype.setUTCDay=function(x){return d.setUTCDay(x);}
    window.Date.prototype.setUTCHours=function(x){return d.setUTCHours(x);}
    window.Date.prototype.setUTCMinutes=function(x){return d.setUTCMinutes(x);}
    window.Date.prototype.setUTCSeconds=function(x){return d.setUTCSeconds(x);}
    window.Date.prototype.setUTCMilliseconds=
        function(x) {return d.setUTCMilliseconds(x);}
  
    window.Date.prototype.toUTCString=function(){return d.toUTCString();}
    window.Date.prototype.toGMTString=function(){return d.toGMTString();}
    window.Date.prototype.toString=function(){return d.toUTCString();}
    window.Date.prototype.toLocaleString=function(){return d.toUTCString();}
    
    /* Fuck 'em if they can't take a joke: */
    window.Date.prototype.toLocaleTimeString=function(){return d.toUTCString();}
    window.Date.prototype.toLocaleDateString=function(){return d.toUTCString();}
    window.Date.prototype.toDateString=function(){return d.toUTCString();}
    window.Date.prototype.toTimeString=function(){return d.toUTCString();}
    
    /* Hack to solve the problem of multiple date objects
     * all sharing the same lexically scoped d every time a new one is
     * created. This hack creates a fresh new prototype reference for 
     * the next object to use with a different d binding.
     * It doesn't break stuff because at the start of this function, 
     * the interpreter grabbed a reference to Date.prototype. During 
     * this function we modified Date.prototype to create the new methods
     * with the lexically scoped d reference.
     */

    // valueOf gets called for implicit string conversion??
    window.Date.prototype = window.eval(window.Object.prototype.toSource());
    return d.toUTCString();
  }

  // Need to do this madness so that we use the window's notion of Function
  // for the constructor. If this is not done, then changes to Function
  // and Object in the real window are not propogated to Date (for example,
  // to extend the Date class with extra functions via a generic inheritance 
  // framework added onto Object - this is done by livejournal and others)
  var newWrappedDate = window.eval("function() { return newDate(); }");

  newWrappedDate.parse=function(s) {
    var d = new origDate(s);
    if(typeof(s) == "string") reparseDate(d, s);
    return d.getTime();    
  }

  newWrappedDate.now=function(){return origDate.now();}
  newWrappedDate.UTC=function(){return origDate.apply(origDate, arguments); }

  // d = new Date();
  // d.__proto__ === Date.prototype
  // d.constructor === Date
  // d.__proto__ === d.constructor.prototype
  // Date.prototype.__proto__  ===  Date.prototype.constructor.prototype 
  // window.__proto__ === Window.prototypea
  
  // XXX: This is still not enough.. But at least we get to claim the 
  // unmasking is violating ECMA-262 by allowing the deletion of var's 
  // (FF Bug 419598)
  with(window) {
    var Date = newWrappedDate;
  }

  } // window.__tb_hook_date == true
  

  with(window) {
      XPCNativeWrapper = function(a) { return a; };
  }
  with(window.__proto__) {
      XPCNativeWrapper = function(a) { return a; };
  }

  // Gain access to the implict global object (which interestingly claims
  // to be a 'Window' but is not the same class as 'window'...) and 
  // hide XPCNativeWrapper there.
  // This seems no longer necessary in FF2.0.0.13+, and may break FF3?
  with(window.valueOf.call().__proto__) {
      XPCNativeWrapper = function(a) { return a; };
  }

  window.__proto__ = null; // Prevent delete from unmasking our properties.
  return true;
}

if (typeof(window.__HookObjects) != "undefined") {
    var res = 23;

    if(!window.__HookObjects()) {
        res = 13;
    }

    window.__HookObjects = undefined;
    delete window['__HookObjects'];
    delete window['__CheckFlag'];
    delete window['__tb_set_uagent'];
    delete window['__tb_oscpu'];
    delete window['__tb_platform'];
    delete window['__tb_productSub'];

    window.__tb_hooks_ran = true;

    res; // Secret result code.
} else {
    42;
}
