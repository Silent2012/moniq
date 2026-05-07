#!/usr/bin/env python3
"""
Generates moniq.xcodeproj/project.pbxproj from the source tree.
Run from /Users/james/Projects/moniq/
"""

import os
import uuid
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ_NAME = "moniq"
BUNDLE_ID = "com.moniq.app"
DEPLOYMENT_TARGET = "13.0"
SWIFT_VERSION = "5.9"

def uid():
    return uuid.uuid4().hex[:24].upper()

# ── Collect all Swift source files ──────────────────────────────────────────
source_files = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    # Skip the xcodeproj itself and hidden dirs
    dirnames[:] = [d for d in dirnames if not d.startswith('.') and not d.endswith('.xcodeproj')]
    for fn in filenames:
        if fn.endswith('.swift'):
            full = os.path.join(dirpath, fn)
            rel  = os.path.relpath(full, ROOT)
            source_files.append(rel)

source_files.sort()

# ── Collect entitlements & Info.plist (resource/support files) ──────────────
support_files = []
for fn in ['moniq.entitlements']:
    if os.path.exists(os.path.join(ROOT, fn)):
        support_files.append(fn)

# ── Assign UUIDs ─────────────────────────────────────────────────────────────
# File references
file_ref_ids   = {f: uid() for f in source_files + support_files}

# Build file refs (source files only)
build_file_ids = {f: uid() for f in source_files}

# Groups — we'll create a flat mapping of folder → group ID
groups = {}
all_dirs = set()
for f in source_files:
    parts = f.split(os.sep)
    for i in range(len(parts)):
        d = os.sep.join(parts[:i]) if i > 0 else ''
        all_dirs.add(d)

for d in sorted(all_dirs):
    groups[d] = uid()

main_group_id  = groups['']
products_group = uid()

# Target IDs
target_id          = uid()
project_id         = uid()
sources_phase_id   = uid()
frameworks_phase_id= uid()
resources_phase_id = uid()

# Config IDs
debug_config_id    = uid()
release_config_id  = uid()
proj_debug_id      = uid()
proj_release_id    = uid()
target_config_list = uid()
proj_config_list   = uid()

# Product file ref
product_ref_id = uid()

# ── Frameworks ───────────────────────────────────────────────────────────────
frameworks = ['IOKit.framework', 'Cocoa.framework']
fw_ref_ids   = {f: uid() for f in frameworks}
fw_build_ids = {f: uid() for f in frameworks}

# ── Build the pbxproj string ─────────────────────────────────────────────────
def pbx_file_ref(ref_id, path, source_tree="SOURCE_ROOT", file_type=None):
    if file_type is None:
        if path.endswith('.swift'):
            file_type = 'sourcecode.swift'
        elif path.endswith('.entitlements'):
            file_type = 'text.plist.entitlements'
        elif path.endswith('.plist'):
            file_type = 'text.plist.xml'
        elif path.endswith('.framework'):
            file_type = 'wrapper.framework'
            source_tree = 'SDKROOT'
        else:
            file_type = 'file'
    name = os.path.basename(path)
    return (
        f'\t\t{ref_id} = {{\n'
        f'\t\t\tisa = PBXFileReference;\n'
        f'\t\t\tlastKnownFileType = {file_type};\n'
        f'\t\t\tname = "{name}";\n'
        f'\t\t\tpath = "{path}";\n'
        f'\t\t\tsourceTree = {source_tree};\n'
        f'\t\t}};\n'
    )

lines = ['// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {\n']

# ── PBXBuildFile ─────────────────────────────────────────────────────────────
lines.append('\n/* Begin PBXBuildFile section */\n')
for f in source_files:
    lines.append(f'\t\t{build_file_ids[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_ids[f]} /* {os.path.basename(f)} */; }};\n')
for fw in frameworks:
    lines.append(f'\t\t{fw_build_ids[fw]} /* {fw} in Frameworks */ = {{isa = PBXBuildFile; fileRef = {fw_ref_ids[fw]} /* {fw} */; }};\n')
lines.append('/* End PBXBuildFile section */\n')

# ── PBXFileReference ─────────────────────────────────────────────────────────
lines.append('\n/* Begin PBXFileReference section */\n')
for f in source_files:
    lines.append(pbx_file_ref(file_ref_ids[f], f))
for f in support_files:
    lines.append(pbx_file_ref(file_ref_ids[f], f))
for fw in frameworks:
    lines.append(pbx_file_ref(fw_ref_ids[fw], f'System/Library/Frameworks/{fw}', source_tree='SDKROOT', file_type='wrapper.framework'))
# Product
lines.append(
    f'\t\t{product_ref_id} = {{\n'
    f'\t\t\tisa = PBXFileReference;\n'
    f'\t\t\texplicitFileType = wrapper.application;\n'
    f'\t\t\tincludeInIndex = 0;\n'
    f'\t\t\tpath = "{PROJ_NAME}.app";\n'
    f'\t\t\tsourceTree = BUILT_PRODUCTS_DIR;\n'
    f'\t\t}};\n'
)
lines.append('/* End PBXFileReference section */\n')

# ── PBXFrameworksBuildPhase ──────────────────────────────────────────────────
lines.append('\n/* Begin PBXFrameworksBuildPhase section */\n')
fw_files = '\n'.join(f'\t\t\t\t{fw_build_ids[fw]} /* {fw} in Frameworks */,' for fw in frameworks)
lines.append(
    f'\t\t{frameworks_phase_id} = {{\n'
    f'\t\t\tisa = PBXFrameworksBuildPhase;\n'
    f'\t\t\tbuildActionMask = 2147483647;\n'
    f'\t\t\tfiles = (\n'
    f'{fw_files}\n'
    f'\t\t\t);\n'
    f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
    f'\t\t}};\n'
)
lines.append('/* End PBXFrameworksBuildPhase section */\n')

# ── PBXGroup ─────────────────────────────────────────────────────────────────
lines.append('\n/* Begin PBXGroup section */\n')

# Build a tree: parent → children dirs + files
from collections import defaultdict
dir_children  = defaultdict(list)   # dir → [subdir, ...]
dir_files     = defaultdict(list)   # dir → [file_rel, ...]

for f in source_files:
    parts = f.split(os.sep)
    parent = os.sep.join(parts[:-1]) if len(parts) > 1 else ''
    dir_files[parent].append(f)

all_group_dirs = sorted(groups.keys())
for d in all_group_dirs:
    if d == '':
        continue
    parent = os.sep.join(d.split(os.sep)[:-1])
    dir_children[parent].append(d)

def group_children_str(d):
    items = []
    for child_dir in sorted(dir_children.get(d, [])):
        name = os.path.basename(child_dir)
        items.append(f'\t\t\t\t{groups[child_dir]} /* {name} */,')
    for f in sorted(dir_files.get(d, [])):
        name = os.path.basename(f)
        items.append(f'\t\t\t\t{file_ref_ids[f]} /* {name} */,')
    return '\n'.join(items)

for d in all_group_dirs:
    gid  = groups[d]
    name = os.path.basename(d) if d else PROJ_NAME
    children = group_children_str(d)
    if d == '':
        # Root group also has Products
        children += f'\n\t\t\t\t{products_group} /* Products */,'
    source_tree = '"<group>"'
    path_line = f'\t\t\tpath = "{d}";\n' if d != '' else ''
    lines.append(
        f'\t\t{gid} = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'{children}\n'
        f'\t\t\t);\n'
        f'\t\t\tname = "{name}";\n'
        f'{path_line}'
        f'\t\t\tsourceTree = {source_tree};\n'
        f'\t\t}};\n'
    )

# Products group
lines.append(
    f'\t\t{products_group} = {{\n'
    f'\t\t\tisa = PBXGroup;\n'
    f'\t\t\tchildren = (\n'
    f'\t\t\t\t{product_ref_id} /* {PROJ_NAME}.app */,\n'
    f'\t\t\t);\n'
    f'\t\t\tname = Products;\n'
    f'\t\t\tsourceTree = "<group>";\n'
    f'\t\t}};\n'
)
lines.append('/* End PBXGroup section */\n')

# ── PBXNativeTarget ──────────────────────────────────────────────────────────
lines.append('\n/* Begin PBXNativeTarget section */\n')
lines.append(
    f'\t\t{target_id} = {{\n'
    f'\t\t\tisa = PBXNativeTarget;\n'
    f'\t\t\tbuildConfigurationList = {target_config_list};\n'
    f'\t\t\tbuildPhases = (\n'
    f'\t\t\t\t{sources_phase_id} /* Sources */,\n'
    f'\t\t\t\t{frameworks_phase_id} /* Frameworks */,\n'
    f'\t\t\t\t{resources_phase_id} /* Resources */,\n'
    f'\t\t\t);\n'
    f'\t\t\tbuildRules = (\n'
    f'\t\t\t);\n'
    f'\t\t\tdependencies = (\n'
    f'\t\t\t);\n'
    f'\t\t\tname = {PROJ_NAME};\n'
    f'\t\t\tproductName = {PROJ_NAME};\n'
    f'\t\t\tproductReference = {product_ref_id};\n'
    f'\t\t\tproductType = "com.apple.product-type.application";\n'
    f'\t\t}};\n'
)
lines.append('/* End PBXNativeTarget section */\n')

# ── PBXProject ───────────────────────────────────────────────────────────────
lines.append('\n/* Begin PBXProject section */\n')
lines.append(
    f'\t\t{project_id} = {{\n'
    f'\t\t\tisa = PBXProject;\n'
    f'\t\t\tattributes = {{\n'
    f'\t\t\t\tLastSwiftUpdateCheck = 1500;\n'
    f'\t\t\t\tLastUpgradeCheck = 1500;\n'
    f'\t\t\t\tTargetAttributes = {{\n'
    f'\t\t\t\t\t{target_id} = {{\n'
    f'\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n'
    f'\t\t\t\t\t}};\n'
    f'\t\t\t\t}};\n'
    f'\t\t\t}};\n'
    f'\t\t\tbuildConfigurationList = {proj_config_list};\n'
    f'\t\t\tcompatibilityVersion = "Xcode 14.0";\n'
    f'\t\t\tdevelopmentRegion = en;\n'
    f'\t\t\thasScannedForEncodings = 0;\n'
    f'\t\t\tknownRegions = (\n'
    f'\t\t\t\ten,\n'
    f'\t\t\t\tBase,\n'
    f'\t\t\t);\n'
    f'\t\t\tmainGroup = {main_group_id};\n'
    f'\t\t\tproductRefGroup = {products_group};\n'
    f'\t\t\tprojectDirPath = "";\n'
    f'\t\t\tprojectRoot = "";\n'
    f'\t\t\ttargets = (\n'
    f'\t\t\t\t{target_id} /* {PROJ_NAME} */,\n'
    f'\t\t\t);\n'
    f'\t\t}};\n'
)
lines.append('/* End PBXProject section */\n')

# ── PBXResourcesBuildPhase ───────────────────────────────────────────────────
lines.append('\n/* Begin PBXResourcesBuildPhase section */\n')
lines.append(
    f'\t\t{resources_phase_id} = {{\n'
    f'\t\t\tisa = PBXResourcesBuildPhase;\n'
    f'\t\t\tbuildActionMask = 2147483647;\n'
    f'\t\t\tfiles = (\n'
    f'\t\t\t);\n'
    f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
    f'\t\t}};\n'
)
lines.append('/* End PBXResourcesBuildPhase section */\n')

# ── PBXSourcesBuildPhase ─────────────────────────────────────────────────────
lines.append('\n/* Begin PBXSourcesBuildPhase section */\n')
src_files_str = '\n'.join(
    f'\t\t\t\t{build_file_ids[f]} /* {os.path.basename(f)} in Sources */,'
    for f in source_files
)
lines.append(
    f'\t\t{sources_phase_id} = {{\n'
    f'\t\t\tisa = PBXSourcesBuildPhase;\n'
    f'\t\t\tbuildActionMask = 2147483647;\n'
    f'\t\t\tfiles = (\n'
    f'{src_files_str}\n'
    f'\t\t\t);\n'
    f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
    f'\t\t}};\n'
)
lines.append('/* End PBXSourcesBuildPhase section */\n')

# ── XCBuildConfiguration ─────────────────────────────────────────────────────
common_settings = f'''\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};
\t\t\t\tSDKROOT = macosx;'''

target_settings = f'''\t\t\t\tCODE_SIGN_ENTITLEMENTS = moniq.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tINFOPLIST_FILE = moniq/Info.plist;
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;'''

lines.append('\n/* Begin XCBuildConfiguration section */\n')

# Project Debug
lines.append(
    f'\t\t{proj_debug_id} = {{\n'
    f'\t\t\tisa = XCBuildConfiguration;\n'
    f'\t\t\tbuildSettings = {{\n'
    f'{common_settings}\n'
    f'\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");\n'
    f'\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n'
    f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n'
    f'\t\t\t}};\n'
    f'\t\t\tname = Debug;\n'
    f'\t\t}};\n'
)
# Project Release
lines.append(
    f'\t\t{proj_release_id} = {{\n'
    f'\t\t\tisa = XCBuildConfiguration;\n'
    f'\t\t\tbuildSettings = {{\n'
    f'{common_settings}\n'
    f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";\n'
    f'\t\t\t\tVALIDATE_PRODUCT = YES;\n'
    f'\t\t\t}};\n'
    f'\t\t\tname = Release;\n'
    f'\t\t}};\n'
)
# Target Debug
lines.append(
    f'\t\t{debug_config_id} = {{\n'
    f'\t\t\tisa = XCBuildConfiguration;\n'
    f'\t\t\tbuildSettings = {{\n'
    f'{target_settings}\n'
    f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n'
    f'\t\t\t}};\n'
    f'\t\t\tname = Debug;\n'
    f'\t\t}};\n'
)
# Target Release
lines.append(
    f'\t\t{release_config_id} = {{\n'
    f'\t\t\tisa = XCBuildConfiguration;\n'
    f'\t\t\tbuildSettings = {{\n'
    f'{target_settings}\n'
    f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";\n'
    f'\t\t\t}};\n'
    f'\t\t\tname = Release;\n'
    f'\t\t}};\n'
)
lines.append('/* End XCBuildConfiguration section */\n')

# ── XCConfigurationList ───────────────────────────────────────────────────────
lines.append('\n/* Begin XCConfigurationList section */\n')
lines.append(
    f'\t\t{proj_config_list} = {{\n'
    f'\t\t\tisa = XCConfigurationList;\n'
    f'\t\t\tbuildConfigurations = (\n'
    f'\t\t\t\t{proj_debug_id} /* Debug */,\n'
    f'\t\t\t\t{proj_release_id} /* Release */,\n'
    f'\t\t\t);\n'
    f'\t\t\tdefaultConfigurationIsVisible = 0;\n'
    f'\t\t\tdefaultConfigurationName = Release;\n'
    f'\t\t}};\n'
)
lines.append(
    f'\t\t{target_config_list} = {{\n'
    f'\t\t\tisa = XCConfigurationList;\n'
    f'\t\t\tbuildConfigurations = (\n'
    f'\t\t\t\t{debug_config_id} /* Debug */,\n'
    f'\t\t\t\t{release_config_id} /* Release */,\n'
    f'\t\t\t);\n'
    f'\t\t\tdefaultConfigurationIsVisible = 0;\n'
    f'\t\t\tdefaultConfigurationName = Release;\n'
    f'\t\t}};\n'
)
lines.append('/* End XCConfigurationList section */\n')

# ── Closing ───────────────────────────────────────────────────────────────────
lines.append('\t};\n')
lines.append(f'\trootObject = {project_id};\n')
lines.append('}\n')

# ── Write output ─────────────────────────────────────────────────────────────
proj_dir = os.path.join(ROOT, f'{PROJ_NAME}.xcodeproj')
os.makedirs(proj_dir, exist_ok=True)
pbxproj_path = os.path.join(proj_dir, 'project.pbxproj')
with open(pbxproj_path, 'w') as f:
    f.writelines(lines)

print(f'✅  Generated {pbxproj_path}')
print(f'    {len(source_files)} Swift source files included')
print(f'\nNext: open {PROJ_NAME}.xcodeproj')
