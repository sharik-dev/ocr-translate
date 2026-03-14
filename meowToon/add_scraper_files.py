import sys
import os
import re
import binascii

pbxproj_path = "meowToon.xcodeproj/project.pbxproj"

with open(pbxproj_path, "r") as f:
    content = f.read()

def add_file(filename, file_type="sourcecode.swift", is_resource=False):
    global content
    
    file_ref_id = binascii.hexlify(os.urandom(12)).decode('ascii').upper()
    build_file_id = binascii.hexlify(os.urandom(12)).decode('ascii').upper()
    
    # 1. Add to PBXBuildFile section
    build_file = f"\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n"
    if is_resource:
        build_file = f"\t\t{build_file_id} /* {filename} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n"
    content = re.sub(r'(\/\* Begin PBXBuildFile section \*\/)', r'\1\n' + build_file, content)
    
    # 2. Add to PBXFileReference section
    file_ref = f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {filename}; sourceTree = \"<group>\"; }};\n"
    content = re.sub(r'(\/\* Begin PBXFileReference section \*\/)', r'\1\n' + file_ref, content)
    
    # 3. Add to Groups
    if "View" in filename and not "ViewModel" in filename:
        group_pattern = r'(\/\* Views \*\/ = \{\s*isa = PBXGroup;\s*children = \(\n)'
    elif "ViewModel" in filename or "Manager" in filename:
        group_pattern = r'(\/\* ViewModels \*\/ = \{\s*isa = PBXGroup;\s*children = \(\n)'
    else:
        group_pattern = r'(\/\* Models \*\/ = \{\s*isa = PBXGroup;\s*children = \(\n)'
        
    if re.search(group_pattern, content):
        content = re.sub(group_pattern, r'\1\t\t\t\t' + file_ref_id + f' /* {filename} */,\n', content)
    else:
        # Fallback to main group
        main_group_pattern = r'(isa = PBXGroup;\s*children = \(\n)'
        content = re.sub(main_group_pattern, r'\1\t\t\t\t' + file_ref_id + f' /* {filename} */,\n', content, count=1)
    
    # 4. Add to Build Phase
    sources_phase = r'(isa = PBXSourcesBuildPhase;\s*buildActionMask = [0-9]+;\s*files = \(\n)'
    content = re.sub(sources_phase, r'\1\t\t\t\t' + build_file_id + f' /* {filename} in Sources */,\n', content)
    
    print(f"Added {filename}")

add_file("HiddenWebViewManager.swift")
add_file("CaptchaResolverView.swift")

with open(pbxproj_path, "w") as f:
    f.write(content)
