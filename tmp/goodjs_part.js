(window.webpackJsonp = window.webpackJsonp || []).push([
  [72],
  {
    "+6XX": function (e, t, n) {
      var r = n("y1pI");
      e.exports = function (e) {
        return -1 < r(this.__data__, e);
      };
    },
    "+924": function (e, t, n) {
      "use strict";
      n.d(t, "d", function () {
        return o;
      }),
        n.d(t, "c", function () {
          return i;
        }),
        n.d(t, "b", function () {
          return a;
        }),
        n.d(t, "a", function () {
          return u;
        });
      var r = n("9AQC");
      function o(e, t) {
        return (
          void 0 === t && (t = 0),
          "string" != typeof e || 0 === t || e.length <= t
            ? e
            : e.substr(0, t) + "..."
        );
      }
      function i(e, t) {
        var n = e,
          r = n.length;
        if (r <= 150) return n;
        r < t && (t = r);
        e = Math.max(t - 60, 0);
        e < 5 && (e = 0);
        t = Math.min(e + 140, r);
        return (
          (t = r - 5 < t ? r : t) === r && (e = Math.max(t - 140, 0)),
          (n = n.slice(e, t)),
          0 < e && (n = "'{snip} " + n),
          t < r && (n += " {snip}"),
          n
        );
      }
      function a(e, t) {
        if (!Array.isArray(e)) return "";
        for (var n = [], r = 0; r < e.length; r++) {
          var o = e[r];
          try {
            n.push(String(o));
          } catch (e) {
            n.push("[value cannot be serialized]");
          }
        }
        return n.join(t);
      }
      function u(e, t) {
        return (
          !!Object(r.k)(e) &&
          (Object(r.j)(t)
            ? t.test(e)
            : "string" == typeof t && -1 !== e.indexOf(t))
        );
      }
    },
    "+A1k": function (e, r, o) {
      "use strict";
      !function (e) {
        function t() {
          return (
            "[object process]" ===
            Object.prototype.toString.call(void 0 !== e ? e : 0)
          );
        }
        function n(e, t) {
          return e.require(t);
        }
        o.d(r, "b", function () {
          return t;
        }),
          o.d(r, "a", function () {
            return n;
          });
      }.call(this, o("8oxB"));
    },
    "+K+b": function (e, t, n) {
      var r = n("JHRd");
      e.exports = function (e) {
        var t = new e.constructor(e.byteLength);
        return new r(t).set(new r(e)), t;
      };
    },
    "+Qka": function (e, t, n) {
      var l = n("fmRc"),
        c = n("t2Dn"),
        p = n("cq/+"),
        f = n("T1AV"),
        d = n("GoyQ"),
        h = n("mTTR"),
        m = n("itsj");
      e.exports = function r(o, i, a, u, s) {
        o !== i &&
          p(
            i,
            function (e, t) {
              var n;
              (s = s || new l()),
                d(e)
                  ? f(o, i, t, a, r, u, s)
                  : ((n = u ? u(m(o, t), e, t + "", o, i, s) : void 0),
                    c(o, t, (n = void 0 === n ? e : n)));
            },
            h
          );
      };
    },
    "+c4W": function (e, t, n) {
      var r = n("711d"),
        o = n("4/ic"),
        i = n("9ggG"),
        a = n("9Nap");
      e.exports = function (e) {
        return i(e) ? r(a(e)) : o(e);
      };
    },
    "+iFO": function (e, t, n) {
      var r = n("dTAl"),
        o = n("LcsW"),
        i = n("6sVZ");
      e.exports = function (e) {
        return "function" != typeof e.constructor || i(e) ? {} : r(o(e));
      };
    },
    "+lvF": function (e, t, n) {
      e.exports = n("VTer")("native-function-to-string", Function.toString);
    },
    "+rLv": function (e, t, n) {
      n = n("dyZX").document;
      e.exports = n && n.documentElement;
    },
    "+wdc": function (e, u, t) {
      "use strict";
      var i, s, l, n, r, o, a, c, p, f, d, h, m, y, v, g, b, x, w, _;
      function k(e, t) {
        var n = e.length;
        e.push(t);
        e: for (;;) {
          var r = (n - 1) >>> 1,
            o = e[r];
          if (!(void 0 !== o && 0 < S(o, t))) break e;
          (e[r] = t), (e[n] = o), (n = r);
        }
      }
      function E(e) {
        return void 0 === (e = e[0]) ? null : e;
      }
      function O(e) {
        var t = e[0];
        if (void 0 !== t) {
          var n = e.pop();
          if (n !== t) {
            e[0] = n;
            e: for (var r = 0, o = e.length; r < o; ) {
              var i = 2 * (r + 1) - 1,
                a = e[i],
                u = 1 + i,
                s = e[u];
              if (void 0 !== a && S(a, n) < 0)
                r =
                  void 0 !== s && S(s, a) < 0
                    ? ((e[r] = s), (e[u] = n), u)
                    : ((e[r] = a), (e[i] = n), i);
              else {
                if (!(void 0 !== s && S(s, n) < 0)) break e;
                (e[r] = s), (e[u] = n), (r = u);
              }
            }
          }
          return t;
        }
      }
      function S(e, t) {
        var n = e.sortIndex - t.sortIndex;
        return 0 != n ? n : e.id - t.id;
      }
      "undefined" == typeof window || "function" != typeof MessageChannel
        ? ((r = n = null),
          (o = function () {
            if (null !== n)
              try {
                var e = u.unstable_now();
                n(!0, e), (n = null);
              } catch (e) {
                throw (setTimeout(o, 0), e);
              }
          }),
          (a = Date.now()),
          (u.unstable_now = function () {
            return Date.now() - a;
          }),
          (i = function (e) {
            null !== n ? setTimeout(i, 0, e) : ((n = e), setTimeout(o, 0));
          }),
          (s = function (e, t) {
            r = setTimeout(e, t);
          }),
          (l = function () {
            clearTimeout(r);
          }),
          (x = function () {
            return !1;
          }),
          (z = u.unstable_forceFrameRate = function () {}))
        : ((c = window.performance),
          (p = window.Date),
          (f = window.setTimeout),
          (d = window.clearTimeout),
          "undefined" != typeof console &&
            ((w = window.cancelAnimationFrame),
            "function" != typeof window.requestAnimationFrame &&
              console.error(
                "This browser doesn't support requestAnimationFrame. Make sure that you load a polyfill in older browsers. https://fb.me/react-polyfills"
              ),
            "function" != typeof w &&
              console.error(
                "This browser doesn't support cancelAnimationFrame. Make sure that you load a polyfill in older browsers. https://fb.me/react-polyfills"
              )),
          "object" == typeof c && "function" == typeof c.now
            ? (u.unstable_now = function () {
                return c.now();
              })
            : ((h = p.now()),
              (u.unstable_now = function () {
                return p.now() - h;
              })),
          (m = !1),
          (y = null),
          (v = -1),
          (g = 5),
          (b = 0),
          (x = function () {
            return u.unstable_now() >= b;
          }),
          (z = function () {}),
          (u.unstable_forceFrameRate = function (e) {
            e < 0 || 125 < e
              ? console.error(
                  "forceFrameRate takes a positive int between 0 and 125, forcing framerates higher than 125 fps is not unsupported"
                )
              : (g = 0 < e ? Math.floor(1e3 / e) : 5);
          }),
          (w = new MessageChannel()),
          (_ = w.port2),
          (w.port1.onmessage = function () {
            if (null !== y) {
              var e = u.unstable_now();
              b = e + g;
              try {
                y(!0, e) ? _.postMessage(null) : ((m = !1), (y = null));
              } catch (e) {
                throw (_.postMessage(null), e);
              }
            } else m = !1;
          }),
          (i = function (e) {
            (y = e), m || ((m = !0), _.postMessage(null));
          }),
          (s = function (e, t) {
            v = f(function () {
              e(u.unstable_now());
            }, t);
          }),
          (l = function () {
            d(v), (v = -1);
          }));
      var T = [],
        j = [],
        C = 1,
        P = null,
        R = 3,
        M = !1,
        N = !1,
        A = !1;
      function I(e) {
        for (var t = E(j); null !== t; ) {
          if (null === t.callback) O(j);
          else {
            if (!(t.startTime <= e)) break;
            O(j), (t.sortIndex = t.expirationTime), k(T, t);
          }
          t = E(j);
        }
      }
      function L(e) {
        var t;
        (A = !1),
          I(e),
          N ||
            (null !== E(T)
              ? ((N = !0), i(F))
              : null !== (t = E(j)) && s(L, t.startTime - e));
      }
      function F(e, t) {
        (N = !1), A && ((A = !1), l()), (M = !0);
        var n = R;
        try {
          for (
            I(t), P = E(T);
            null !== P && (!(P.expirationTime > t) || (e && !x()));

          ) {
            var r,
              o = P.callback;
            null !== o
              ? ((P.callback = null),
                (R = P.priorityLevel),
                (r = o(P.expirationTime <= t)),
                (t = u.unstable_now()),
                "function" == typeof r ? (P.callback = r) : P === E(T) && O(T),
                I(t))
              : O(T),
              (P = E(T));
          }
          var i,
            a =
              null !== P || (null !== (i = E(j)) && s(L, i.startTime - t), !1);
          return a;
        } finally {
          (P = null), (R = n), (M = !1);
        }
      }
      function D(e) {
        switch (e) {
          case 1:
            return -1;
          case 2:
            return 250;
          case 5:
            return 1073741823;
          case 4:
            return 1e4;
          default:
            return 5e3;
        }
      }
      var z = z;
      (u.unstable_IdlePriority = 5),
        (u.unstable_ImmediatePriority = 1),
        (u.unstable_LowPriority = 4),
        (u.unstable_NormalPriority = 3),
        (u.unstable_Profiling = null),
        (u.unstable_UserBlockingPriority = 2),
        (u.unstable_cancelCallback = function (e) {
          e.callback = null;
        }),
        (u.unstable_continueExecution = function () {
          N || M || ((N = !0), i(F));
        }),
        (u.unstable_getCurrentPriorityLevel = function () {
          return R;
        }),
        (u.unstable_getFirstCallbackNode = function () {
          return E(T);
        }),
        (u.unstable_next = function (e) {
          switch (R) {
            case 1:
            case 2:
            case 3:
              var t = 3;
              break;
            default:
              t = R;
          }
          var n = R;
          R = t;
          try {
            return e();
          } finally {
            R = n;
          }
        }),
        (u.unstable_pauseExecution = function () {}),
        (u.unstable_requestPaint = z),
        (u.unstable_runWithPriority = function (e, t) {
          switch (e) {
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
              break;
            default:
              e = 3;
          }
          var n = R;
          R = e;
          try {
            return t();
          } finally {
            R = n;
          }
        }),
        (u.unstable_scheduleCallback = function (e, t, n) {
          var r,
            o = u.unstable_now();
          return (
            "object" == typeof n && null !== n
              ? ((r = "number" == typeof (r = n.delay) && 0 < r ? o + r : o),
                (n = "number" == typeof n.timeout ? n.timeout : D(e)))
              : ((n = D(e)), (r = o)),
            (e = {
              id: C++,
              callback: t,
              priorityLevel: e,
              startTime: r,
              expirationTime: (n = r + n),
              sortIndex: -1,
            }),
            o < r
              ? ((e.sortIndex = r),
                k(j, e),
                null === E(T) &&
                  e === E(j) &&
                  (A ? l() : (A = !0), s(L, r - o)))
              : ((e.sortIndex = n), k(T, e), N || M || ((N = !0), i(F))),
            e
          );
        }),
        (u.unstable_shouldYield = function () {
          var e = u.unstable_now();
          I(e);
          var t = E(T);
          return (
            (t !== P &&
              null !== P &&
              null !== t &&
              null !== t.callback &&
              t.startTime <= e &&
              t.expirationTime < P.expirationTime) ||
            x()
          );
        }),
        (u.unstable_wrapCallback = function (t) {
          var n = R;
          return function () {
            var e = R;
            R = n;
            try {
              return t.apply(this, arguments);
            } finally {
              R = e;
            }
          };
        });
    },
    "//Lv": function (e, t, n) {
      "use strict";
      e.exports = {
        ach: {
          name: "Acholi",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n > 1)",
          pluralsFunc: function (e) {
            return 1 < e;
          },
        },
        af: {
          name: "Afrikaans",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        ak: {
          name: "Akan",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n > 1)",
          pluralsFunc: function (e) {
            return 1 < e;
          },
        },
        am: {
          name: "Amharic",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n > 1)",
          pluralsFunc: function (e) {
            return 1 < e;
          },
        },
        an: {
          name: "Aragonese",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        ar: {
          name: "Arabic",
          examples: [
            { plural: 0, sample: 0 },
            { plural: 1, sample: 1 },
            { plural: 2, sample: 2 },
            { plural: 3, sample: 3 },
            { plural: 4, sample: 11 },
            { plural: 5, sample: 100 },
          ],
          nplurals: 6,
          pluralsText:
            "nplurals = 6; plural = (n === 0 ? 0 : n === 1 ? 1 : n === 2 ? 2 : n % 100 >= 3 && n % 100 <= 10 ? 3 : n % 100 >= 11 ? 4 : 5)",
          pluralsFunc: function (e) {
            return 0 === e
              ? 0
              : 1 === e
              ? 1
              : 2 === e
              ? 2
              : 3 <= e % 100 && e % 100 <= 10
              ? 3
              : 11 <= e % 100
              ? 4
              : 5;
          },
        },
        arn: {
          name: "Mapudungun",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n > 1)",
          pluralsFunc: function (e) {
            return 1 < e;
          },
        },
        ast: {
          name: "Asturian",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        ay: {
          name: "Aymará",
          examples: [{ plural: 0, sample: 1 }],
          nplurals: 1,
          pluralsText: "nplurals = 1; plural = 0",
          pluralsFunc: function () {
            return 0;
          },
        },
        az: {
          name: "Azerbaijani",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        be: {
          name: "Belarusian",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
            { plural: 2, sample: 5 },
          ],
          nplurals: 3,
          pluralsText:
            "nplurals = 3; plural = (n % 10 === 1 && n % 100 !== 11 ? 0 : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? 1 : 2)",
          pluralsFunc: function (e) {
            return e % 10 == 1 && e % 100 != 11
              ? 0
              : 2 <= e % 10 && e % 10 <= 4 && (e % 100 < 10 || 20 <= e % 100)
              ? 1
              : 2;
          },
        },
        bg: {
          name: "Bulgarian",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        bn: {
          name: "Bengali",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        bo: {
          name: "Tibetan",
          examples: [{ plural: 0, sample: 1 }],
          nplurals: 1,
          pluralsText: "nplurals = 1; plural = 0",
          pluralsFunc: function () {
            return 0;
          },
        },
        br: {
          name: "Breton",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n > 1)",
          pluralsFunc: function (e) {
            return 1 < e;
          },
        },
        brx: {
          name: "Bodo",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        bs: {
          name: "Bosnian",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
            { plural: 2, sample: 5 },
          ],
          nplurals: 3,
          pluralsText:
            "nplurals = 3; plural = (n % 10 === 1 && n % 100 !== 11 ? 0 : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? 1 : 2)",
          pluralsFunc: function (e) {
            return e % 10 == 1 && e % 100 != 11
              ? 0
              : 2 <= e % 10 && e % 10 <= 4 && (e % 100 < 10 || 20 <= e % 100)
              ? 1
              : 2;
          },
        },
        ca: {
          name: "Catalan",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        cgg: {
          name: "Chiga",
          examples: [{ plural: 0, sample: 1 }],
          nplurals: 1,
          pluralsText: "nplurals = 1; plural = 0",
          pluralsFunc: function () {
            return 0;
          },
        },
        cs: {
          name: "Czech",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
            { plural: 2, sample: 5 },
          ],
          nplurals: 3,
          pluralsText:
            "nplurals = 3; plural = (n === 1 ? 0 : (n >= 2 && n <= 4) ? 1 : 2)",
          pluralsFunc: function (e) {
            return 1 === e ? 0 : 2 <= e && e <= 4 ? 1 : 2;
          },
        },
        csb: {
          name: "Kashubian",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
            { plural: 2, sample: 5 },
          ],
          nplurals: 3,
          pluralsText:
            "nplurals = 3; plural = (n === 1 ? 0 : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? 1 : 2)",
          pluralsFunc: function (e) {
            return 1 === e
              ? 0
              : 2 <= e % 10 && e % 10 <= 4 && (e % 100 < 10 || 20 <= e % 100)
              ? 1
              : 2;
          },
        },
        cy: {
          name: "Welsh",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
            { plural: 2, sample: 3 },
            { plural: 3, sample: 8 },
          ],
          nplurals: 4,
          pluralsText:
            "nplurals = 4; plural = (n === 1 ? 0 : n === 2 ? 1 : (n !== 8 && n !== 11) ? 2 : 3)",
          pluralsFunc: function (e) {
            return 1 === e ? 0 : 2 === e ? 1 : 8 !== e && 11 !== e ? 2 : 3;
          },
        },
        da: {
          name: "Danish",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        de: {
          name: "German",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        doi: {
          name: "Dogri",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        dz: {
          name: "Dzongkha",
          examples: [{ plural: 0, sample: 1 }],
          nplurals: 1,
          pluralsText: "nplurals = 1; plural = 0",
          pluralsFunc: function () {
            return 0;
          },
        },
        el: {
          name: "Greek",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        en: {
          name: "English",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        eo: {
          name: "Esperanto",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        es: {
          name: "Spanish",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        et: {
          name: "Estonian",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        eu: {
          name: "Basque",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        fa: {
          name: "Persian",
          examples: [{ plural: 0, sample: 1 }],
          nplurals: 1,
          pluralsText: "nplurals = 1; plural = 0",
          pluralsFunc: function () {
            return 0;
          },
        },
        ff: {
          name: "Fulah",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        fi: {
          name: "Finnish",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        fil: {
          name: "Filipino",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n > 1)",
          pluralsFunc: function (e) {
            return 1 < e;
          },
        },
        fo: {
          name: "Faroese",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        fr: {
          name: "French",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n > 1)",
          pluralsFunc: function (e) {
            return 1 < e;
          },
        },
        fur: {
          name: "Friulian",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        fy: {
          name: "Frisian",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
          ],
          nplurals: 2,
          pluralsText: "nplurals = 2; plural = (n !== 1)",
          pluralsFunc: function (e) {
            return 1 !== e;
          },
        },
        ga: {
          name: "Irish",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
            { plural: 2, sample: 3 },
            { plural: 3, sample: 7 },
            { plural: 4, sample: 11 },
          ],
          nplurals: 5,
          pluralsText:
            "nplurals = 5; plural = (n === 1 ? 0 : n === 2 ? 1 : n < 7 ? 2 : n < 11 ? 3 : 4)",
          pluralsFunc: function (e) {
            return 1 === e ? 0 : 2 === e ? 1 : e < 7 ? 2 : e < 11 ? 3 : 4;
          },
        },
        gd: {
          name: "Scottish Gaelic",
          examples: [
            { plural: 0, sample: 1 },
            { plural: 1, sample: 2 },
            { plural: 2, sample: 3 },
            { plural: 3, sample: 20 },
          ],
          nplurals: 4,
          pluralsText:
            "nplurals = 4; plural = ((n === 1 || n === 11) ? 0 : (n === 2 || n === 12) ? 1 : (n > 2 && n < 20) ? 2 : 3)",
          pluralsFunc: function (e) {
            return 1 === e || 11 === e
              ? 0
              : 2 === e || 12 === e
              ? 1
              : 2 < e && e < 20
              ? 2
