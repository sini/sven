let
  K = (import ../default.nix).lib.krn;
  fives =
    x:
    K.disj [
      (K.eq x 5)
      (fives x)
    ];
  mem = K.runAllFuel 1000 (
    q:
    K.membero q [
      1
      2
      3
    ]
  );
  fd =
    q:
    K.fresh (
      {
        x,
        y,
        z,
      }:
      [
        (K.infd [ x y ] 1 4)
        (K.infd [ z ] 2 8)
        (K.plusfd x y z)
        (K.label [
          x
          y
          z
        ])
        (K.eq q [
          x
          y
          z
        ])
      ]
    );
  spin = x: K.disj [ (spin x) ];
  inf = K.runAllFuel 50 fives;
  two = K.runFuel 2 1000 fives;
  mx = K.maximize 10000 (a: builtins.elemAt a 2) fd;
  mxTiny = K.maximize 3 (a: builtins.elemAt a 2) fd;
  app = K.runAllFuel 200 (
    q:
    K.fresh (
      { a, b }:
      [
        (K.appendo a b (K.fromList [ 1 ]))
        (K.eq q 1)
      ]
    )
  );
  app2 = K.runAllFuel 200 (
    q:
    K.fresh (
      {
        a,
        b,
        c,
      }:
      [
        (K.appendo a b c)
        (K.eq q [
          a
          b
          c
        ])
      ]
    )
  );
  checks = {
    infinite-incomplete =
      inf.complete == false && inf.answers != [ ] && builtins.all (a: a == 5) inf.answers;
    suspension-fuel = (K.runAllFuel 50 spin).complete == false && (K.runAllFuel 50 spin).answers == [ ];
    infinite-n-complete =
      two.complete == true
      &&
        two.answers == [
          5
          5
        ];
    finite-complete =
      mem.complete == true
      &&
        mem.answers == [
          1
          2
          3
        ];
    finite-low-fuel =
      (K.runAllFuel 1 (
        q:
        K.membero q [
          1
          2
          3
        ]
      )).complete == false;
    maximize-best =
      mx.value == 8
      &&
        mx.best == [
          4
          4
          8
        ]
      && mx.complete == true
      && mx.count == 16;
    maximize-low-fuel = mxTiny.complete == false;
    appendo-unbounded = app2.complete == false && app2.answers != [ ];
    appendo-finite-ok = app.complete == true;
  };
in
{
  inherit checks;
  failed = builtins.filter (n: !checks.${n}) (builtins.attrNames checks);
}
