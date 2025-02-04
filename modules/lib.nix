lib: let
  inherit (lib.lists) elem;
  inherit (lib.strings) concatStringsSep isString;
  inherit (lib.attrsets) attrNames hasAttr isAttrs isDerivation mapAttrs mapAttrs' nameValuePair;
in rec {
  toSnakeCase = string: let
    optionMap = {
      # Services
      blkioConfig = "blkio_config";
      cpuCount = "cpu_count";
      cpuPercent = "cpu_percent";
      cpuShares = "cpu_shares";
      cpuPeriod = "cpu_period";
      cpuQuota = "cpu_quota";
      cpuRtRuntime = "cpu_rt_runtime";
      cpuRtPeriod = "cpu_rt_period";
      capAdd = "cap_add";
      capDrop = "cap_drop";
      cgroupParent = "cgroup_parent";
      credentialSpec = "credential_spec";
      dependsOn = "depends_on";
      deviceCgroupRules = "device_cgroup_rules";
      dnsOpt = "dns_opt";
      dnsSearch = "dns_search";
      driverOpts = "driver_opts";
      envFile = "env_file";
      externalLinks = "external_links";
      extraHosts = "extra_hosts";
      groupAdd = "group_add";
      labelFile = "label_file";
      macAddress = "mac_address";
      memLimit = "mem_limit";
      memReservation = "mem_reservation";
      memSwappiness = "mem_swappiness";
      memswapLimit = "memswap_limit";
      networkMode = "network_mode";
      oomKillDisable = "oom_kill_disable";
      oomScoreAdj = "oom_score_adj";
      pidsLimit = "pids_limit";
      postStart = "post_start";
      preStop = "pre_stop";
      pullPolicy = "pull_policy";
      readOnly = "read_only";
      securityOpt = "security_opt";
      shmSize = "shm_size";
      stdinOpen = "stdin_open";
      stopGracePeriod = "stop_grace_period";
      stopSignal = "stop_signal";
      storageOpt = "storage_opt";
      usernsMode = "userns_mode";
      volumesFrom = "volumes_from";
      workingDir = "working_dir";

      # Networks
      enableIpv6 = "enable_ipv6";
    };
  in
    if hasAttr string optionMap
    then optionMap.${string}
    else string;

  attrsToSnakeCase = attrs:
    mapAttrs' (n: v:
      nameValuePair (toSnakeCase n) (
        if isAttrs v && ! isDerivation v
        then attrsToSnakeCase v
        else v
      ))
    attrs;

  getImageNameFromDerivation = drv: let
    attrNamesOf = attrNames drv;
  in
    if elem "destNameTag" attrNamesOf
    then
      # image coming from dockerTools.pullImage
      drv.destNameTag
    else
      # image coming from dockerTools.buildImage
      if elem "imageName" attrNamesOf && elem "imageTag" attrNamesOf
      then "${drv.imageName}:${drv.imageTag}"
      else
        throw
        "Image '${drv}' is missing the attribute 'destNameTag'. Available attributes: ${
          concatStringsSep "," attrNamesOf
        }";

  getImageName = image:
    if isString image
    then image
    else getImageNameFromDerivation image;

  /*
  * modifications: an attribute set of attribute names and a function to apply on that attribute.
  * attrs:         an attribute set on which we will apply the functions from `mods`.
  *
  * returns `attrs` with the functions of `mods` applied to it.
  */
  modifyAttrs = modifications: attrs:
    mapAttrs (n: v:
      if hasAttr n modifications
      then modifications.${n} v
      else v)
    attrs;
}
