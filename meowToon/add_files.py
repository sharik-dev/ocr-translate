import sys
import os
import re

pbxproj_path = "meowToon.xcodeproj/project.pbxproj"

with open(pbxproj_path, "r") as f:
    content = f.read()

def add_file(filename):
    global content
    
    # Generate UUIDs (simplified, just need to be unique 24-char hex strings)
    # Using python's urandom to get unique hex
    import binascii
    file_ref_id = binascii.hexlify(os.urandom(12)).decode('ascii').upper()
    build_file_id = binascii.hexlify(os.urandom(12)).decode('ascii').upper()
    
    # 1. Add to PBXBuildFile section
    build_file = f"\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n"
    content = re.sub(r'(\/\* Begin PBXBuildFile section \*\/)', r'\1\n' + build_file, content)
    
    # 2. Add to PBXFileReference section
    file_ref = f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    content = re.sub(r'(\/\* Begin PBXFileReference section \*\/)', r'\1\n' + file_ref, content)
    
    # 3. Add to Models Group (Find the Models group children array)
    models_group_pattern = r'(\/\* Models \*\/ = \{\s*isa = PBXGroup;\s*children = \(\n)'
    if re.search(models_group_pattern, content):
        content = re.sub(models_group_pattern, r'\1\t\t\t\t' + file_ref_id + f' /* {filename} */,\n', content)
    else:
        # Fallback to main group if Models not found
        main_group_pattern = r'(isa = PBXGroup;\s*children = \(\n)'
        content = re.sub(main_group_pattern, r'\1\t\t\t\t' + file_ref_id + f' /* {filename} */,\n', content, count=1)
    
    # 4. Add to PBXSourcesBuildPhase
    sources_phase = r'(isa = PBXSourcesBuildPhase;\s*buildActionMask = [0-9]+;\s*files = \(\n)'
    content = re.sub(sources_phase, r'\1\t\t\t\t' + build_file_id + f' /* {filename} in Sources */,\n', content)
    
    print(f"Added {filename}")

add_file("SourceFactory.swift")
add_file("MangaDexSource.swift")

with open(pbxproj_path, "w") as f:
    f.write(content)
