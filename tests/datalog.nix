# datalog oracles. Run: nix-instantiate --eval --strict tests/datalog.nix -A failed   (expect [ ])
let
  D = (import ../default.nix).lib.datalog;
  b = builtins;
  depth = p: if p ? pos && p.pos != [ ] then 1 + b.foldl' (m: x: if x > m then x else m) 0 (map depth p.pos) else 1;

  chain = [ { head = "c"; pos = [ "b" ]; } { head = "b"; pos = [ "a" ]; } { head = "a"; } ];
  mchain = D.wfs chain;
  serves = [ { head = "serves:x"; pos = [ "web:x" ]; neg = [ "drained:x" ]; } { head = "web:x"; } { head = "drained:x"; } ];
  mserves = D.wfs serves;
  even = [ { head = "a"; neg = [ "b" ]; } { head = "b"; neg = [ "a" ]; } ];
  pcycle = [ { head = "p"; pos = [ "q" ]; } { head = "q"; pos = [ "p" ]; } ];

  checks = {
    proofChainDepth = depth (D.proof chain mchain "c") == 3;
    proofChainShape = (D.proof chain mchain "c").pos == [ (D.proof chain mchain "b") ] && (D.proof chain mchain "a").pos == [ ];
    proofFalse = (D.proof serves mserves "serves:x").status or "" == "false";
    proofUndefined = (D.proof even (D.wfs even) "a").status or "" == "undefined";
    proofPosCycleFalse = (D.proof pcycle (D.wfs pcycle) "p").status or "" == "false";
    proofCycleMarker =
      let r = [ { head = "p"; pos = [ "q" ]; } { head = "q"; pos = [ "p" ]; } { head = "p"; } ]; in
      (D.proof r (D.wfs r) "p").pos == [ { atom = "q"; rule = { head = "q"; pos = [ "p" ]; }; pos = [ { atom = "p"; cycle = true; } ]; neg = [ ]; } ];

    whyNotBlocking = b.map (x: x.blocking) (D.whyNot serves mserves "serves:x") == [ [ "drained:x" ] ];
    whyNotMissingEmpty = b.map (x: x.missing) (D.whyNot serves mserves "serves:x") == [ [ ] ];
    whyNotMissing = b.map (x: x.missing) (D.whyNot chain (D.wfs [ { head = "c"; pos = [ "b" ]; } ]) "c") == [ [ "b" ] ];
    whyNotTrue = D.whyNot chain mchain "c" == [ ];
    whyNotNoRule = D.whyNot chain mchain "zzz" == [ { rule = null; reason = "no rule has this head"; } ];
    whyNotUndefined = b.map (x: x.undefinedBody) (D.whyNot even (D.wfs even) "a") == [ [ "b" ] ];

    judgeEven = D.judge even "a" "b" == "unknown";
    judgeSupported = D.judge (D.facts [ "p" ]) "p" "q" == "supported";
    judgeRefuted = D.judge (D.facts [ "p" ]) "q" "p" == "refuted";
    judgeBoth = D.judge (D.facts [ "p" "q" ]) "p" "q" == "both";
    judgeNeither = D.judge [ ] "p" "q" == "neither";
  };
in
{
  inherit checks;
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
