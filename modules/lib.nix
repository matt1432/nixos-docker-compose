lib: let
  inherit (lib.attrsets) attrNames hasAttr isAttrs isDerivation mapAttrs mapAttrs' nameValuePair;
  inherit (lib.lists) elem elemAt;
  inherit (lib.strings) concatStringsSep isString split toLower;

  # From Nixvim
  splitByWords = split "([A-Z])";

  # From Nixvim
  processWord = s:
    if isString s
    then s
    else "_" + toLower (elemAt s 0);
in rec {
  # From Nixvim
  toSnakeCase = string: let
    words = splitByWords string;
  in
    lib.concatStrings (map processWord words);

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
