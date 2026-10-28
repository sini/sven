# clan's inventory in sven: a service instance is data. Each machine spawns one `member` scope per (instance, role)
# it takes part in, so an aspect at a member scope runs once per instance (clan perInstance) and an aspect at the
# machine that `has` a member runs once per machine (clan perMachine). Members read every instance as data.
# Exports are a fleet sink: the engine sets `from` (the member scope), so a service cannot write another's scope.
{ sven, lib, ... }:
let
  inherit (sven.lib) opt;
  attrs = sven.lib.is lib.isAttrs;
  # clan's automatic tags: all, and the machine class
  labelsOf = m: [ "all" (if m.kind == "mac" then "darwin" else "nixos") ] ++ m.labels;
  roleHas = r: m: (r.machines or { }) ? ${m.name} || lib.any (t: lib.elem t (labelsOf m)) (r.tags or [ ]);
  service = i: sven.helpers.clan.services.${i.module} or null;
  # settings: interface defaults, then role-wide, then this machine's (clan finalSettings)
  settingsOf = i: r: m:
    let iface = (service i).roles.${r}.interface or { }; role = i.roles.${r}; in
    lib.foldl' lib.recursiveUpdate (lib.mapAttrs (_: o: o.default or null) iface) [ (role.settings or { }) (role.machines.${m.name}.settings or { }) ];
  all = sven.helpers.clan.instances;
in
{
  sven.kinds.machine.fields.labels = opt (sven.helpers.listOf lib.types.str) [ ];
  sven.kinds.instance.fields = { module = sven.lib.derive lib.types.str (self: self.name); roles = opt attrs { }; };
  sven.helpers.clan = {
    services = { };
    # instances as data, plus the instances services add (clan nested services)
    instances = sven.instance // lib.concatMapAttrs (_: i: (service i).adds or (_: { }) i) sven.instance;
    selectExports = q: lib.filter (e: lib.all (k: e.${k} == q.${k}) (lib.attrNames q));
  };
  sven.kinds.member = { }; # spawned under machines; its elements go up to the machine
  sven.kinds.host.spawns.member = s: sven.helpers.clan.membersOf s;
  sven.kinds.mac.spawns.member = s: sven.helpers.clan.membersOf s;
  sven.helpers.clan.membersOf = m: lib.listToAttrs (lib.concatLists (lib.mapAttrsToList (n: i:
    lib.concatMap (r: lib.optional (roleHas i.roles.${r} m) (lib.nameValuePair "${n}.${r}" {
      instance = n; service = i.module; role = r; settings = settingsOf i r m;
      extraModules = i.roles.${r}.extraModules or [ ];
    })) (lib.attrNames i.roles)) all));

  # one fleet sink for exports; a reader filters by service, instance, role and machine (clan selectExports)
  sven.kinds.fleet.sinks.exports.reduce = es: {
    value = map (e: { inherit (e.from) service instance role; machine = e.from.parent.name; inherit (e) value; }) es;
    errors = [ ];
  };
  sven.aspects.clan-extra-modules = { at = sven.lib.all [ sven.kinds.member (s: s.extraModules != [ ]) ]; os = { member, ... }: { imports = member.extraModules; }; };

  # clan's instance contract: known service and roles, at least one role, machine and instance counts, typed settings
  sven.aspects.clan-contract = {
    at = sven.kinds.fleet;
    errors = { ... }: lib.concatLists (lib.mapAttrsToList (n: i:
      let svc = service i; c = svc.constraints or { }; count = r: lib.length (lib.filter (roleHas i.roles.${r}) (lib.attrValues sven.host ++ lib.attrValues sven.mac)); in
      if svc == null then [ "clan: instance ${n} uses unknown service ${i.module}" ]
      else lib.optional (i.roles == { }) "clan: instance ${n} has no roles"
        ++ map (r: "clan: instance ${n}: service ${i.module} has no role ${r}") (lib.attrNames (removeAttrs i.roles (lib.attrNames svc.roles)))
        ++ lib.concatMap (r: let k = count r; lim = c.roles.${r} or { }; in
             lib.optional (lim ? min && k < lim.min) "clan: instance ${n} role ${r}: ${toString k} machines, at least ${toString lim.min}"
             ++ lib.optional (lim ? max && k > lim.max) "clan: instance ${n} role ${r}: ${toString k} machines, at most ${toString lim.max}")
           (lib.attrNames (lib.intersectAttrs svc.roles i.roles))
        ++ lib.optional (c ? maxInstances && lib.length (lib.attrNames (lib.filterAttrs (_: j: j.module == i.module) all)) > c.maxInstances)
             "clan: instance ${n}: service ${i.module} allows ${toString c.maxInstances} instances") all);
  };
  sven.aspects.clan-settings-typed = {
    at = sven.kinds.member;
    errors = { member, ... }: lib.concatLists (lib.mapAttrsToList (k: o: lib.optional (member.settings.${k} == null || !o.type.check member.settings.${k})
      "clan: ${member.instance}.${member.role}: setting ${k} is not a ${o.type.description}") (sven.helpers.clan.services.${member.service}.roles.${member.role}.interface or { }));
  };
}
