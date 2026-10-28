# Graph algorithms over plain data. A graph is `succ`: an attrset from node name to a list of successor names.
# Builtins only. Every result is in sorted node order, so file order never changes an answer.
let
  b = builtins;
  sort = b.sort b.lessThan;
  uniq =
    xs:
    b.attrNames (
      b.listToAttrs (
        map (x: {
          name = x;
          value = null;
        }) xs
      )
    );
  nodesOf = succ: uniq (b.attrNames succ ++ b.concatLists (b.attrValues succ));
  next = succ: n: sort (succ.${n} or [ ]); # sorted: the order the data is written in never changes an answer
  # nodes reachable by one or more edges (genericClosure: no recursion depth limit)
  reach =
    succ: start:
    sort (
      map (x: x.key) (
        b.genericClosure {
          startSet = map (n: { key = n; }) (next succ start);
          operator = x: map (n: { key = n; }) (next succ x.key);
        }
      )
    );
  transpose =
    succ:
    b.listToAttrs (
      map (n: {
        name = n;
        value = sort (b.filter (m: b.elem n (next succ m)) (nodesOf succ));
      }) (nodesOf succ)
    );
in
rec {
  inherit nodesOf reach transpose;
  # { from; to; } edges to succ
  fromEdges = es: b.mapAttrs (_: xs: sort (map (e: e.to) xs)) (b.groupBy (e: e.from) es);
  # what reaches n (its dependents, for succ = "depends on")
  reachers = succ: reach (transpose succ);
  # nodes on a cycle
  cycles = succ: b.filter (n: b.elem n (reach succ n)) (nodesOf succ);
  # strongly connected components with 2+ nodes or a self loop, each sorted, by first node
  sccs =
    succ:
    let
      t = transpose succ;
      comp = n: sort (uniq ([ n ] ++ b.filter (m: b.elem m (reach t n)) (reach succ n)));
    in
    uniq' (map comp (cycles succ));
  uniq' =
    xss:
    b.attrValues (
      b.listToAttrs (
        map (xs: {
          name = b.concatStringsSep "\n" xs;
          value = xs;
        }) xss
      )
    );
  # Kahn: a node after all its successors (succ = "depends on"). Ties in name order. A cycle is data, not an error.
  topo =
    succ:
    let
      ns = nodesOf succ;
      step =
        acc: _:
        let
          ready = b.filter (n: !b.elem n acc.done && b.all (m: b.elem m acc.done) (next succ n)) acc.left;
        in
        if ready == [ ] then
          acc
        else
          {
            done = acc.done ++ [ (b.head ready) ];
            left = b.filter (n: n != b.head ready) acc.left;
          };
      r = b.foldl' step {
        done = [ ];
        left = ns;
      } ns;
    in
    {
      ok = r.left == [ ];
      order = r.done;
      stuck = r.left;
    };
  # waves: every node in the first wave where all its successors are in earlier waves
  layers =
    succ:
    let
      ns = nodesOf succ;
      go =
        acc: _:
        let
          placed = b.concatLists acc;
          ready = b.filter (n: !b.elem n placed && b.all (m: b.elem m placed) (next succ n)) ns;
        in
        if ready == [ ] then acc else acc ++ [ ready ];
    in
    b.foldl' go [ ] ns;
  # shortest path by edges (breadth first), [ from … to ] or null
  shortest =
    succ: from: to:
    let
      bfs = b.genericClosure {
        startSet = [
          {
            key = from;
            path = [ from ];
          }
        ];
        operator =
          x:
          map (n: {
            key = n;
            path = x.path ++ [ n ];
          }) (next succ x.key);
      };
      hit = b.filter (x: x.key == to) bfs;
    in
    if hit == [ ] then null else (b.head hit).path;
  # every simple path from `from` to `to`
  paths =
    succ: from: to:
    let
      go =
        seen: n:
        if n == to then
          [ [ n ] ]
        else
          b.concatMap (m: if b.elem m seen then [ ] else map (p: [ n ] ++ p) (go (seen ++ [ m ]) m)) (
            next succ n
          );
    in
    if from == to then [ [ from ] ] else go [ from ] from;
}
