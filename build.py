import os
import subprocess as cmd
import sys

dirtyCheck = True

def escapeCli(inArgs):
    outArgs = []
    for arg in inArgs:
        arg = arg.replace("\\", "/") # BAD microsoft >:(
        if " " not in arg and "\"" not in arg:
            outArgs.append(arg)
        else:
            outArgs.append("\"" + arg.replace("\"", "\\\"") + "\"")
    return outArgs

def buildGfxFile(srcPath):
    srcName, srcExt = os.path.splitext(srcPath)
    if srcExt != ".png" or (not srcName.endswith(".1bpp") and not srcName.endswith(".2bpp")):
        return False

    bpp = "1" if srcName.endswith(".1bpp") else "2"
    objPath = os.path.join("build", "gfx", srcName)
    flgPath = srcName + ".flags"
    hasFlg = os.path.exists(flgPath)

    # Ignore file if object is newer
    if os.path.exists(objPath):
        objTime = os.path.getmtime(objPath)
        srcTime = os.path.getmtime(srcPath)
        flgTime = os.path.getmtime(flgPath) if hasFlg else srcTime

        if (objTime >= srcTime and objTime >= flgTime) and dirtyCheck:
            return False

    # Convert file
    os.makedirs(os.path.dirname(objPath), exist_ok=True)
    args = ["rgbgfx", srcPath, "-o", objPath, "-d", bpp]
    if hasFlg:
        args += "-O", "@" + flgPath
    
    print(" ".join(escapeCli(args)))
    result = cmd.run(args, stdout=sys.stdout, stderr=sys.stderr)

    # Mark as error on fail
    return result.returncode != 0

def buildGfxFolder(path):
    totalDirs = []
    isError = False

    for root, dirs, files in os.walk(path):
        totalDirs += dirs
        for filename in files:
            error = buildGfxFile(os.path.join(root, filename))
            isError = isError or error

    for dirname in totalDirs:
        error = buildGfxFolder(os.path.join(root, dirname))
        isError = isError or error
    
    return isError

def buildAsmFile(srcPath):
    srcName, srcExt = os.path.splitext(srcPath)
    if srcExt != ".asm":
        return (None, False)

    objPath = os.path.join("build", "obj", srcName) + ".o"
    depPath = os.path.join("build", "dep", srcName) + ".txt"

    # Object file already exists, should we rebuild?
    if dirtyCheck and os.path.exists(objPath):
        
        # Read dependency file
        dependencies = [srcPath]
        if os.path.exists(depPath):
            depFile = open(depPath)
            for line in depFile: 
                offset = line.find(": ")
                dependency = line[offset + 2:-1]
                if os.path.exists(dependency):
                    dependencies += [dependency]

        # Check if dependencies are newer
        shouldRebuild = False
        objTime = os.path.getmtime(objPath)
        for dependency in dependencies:
            depTime = os.path.getmtime(dependency)
            if depTime >= objTime:
                shouldRebuild = True
        
        # Skip building if no changes
        if not shouldRebuild:
            return (objPath, False)

    # Make directories
    os.makedirs(os.path.dirname(objPath), exist_ok=True)
    os.makedirs(os.path.dirname(depPath), exist_ok=True)

    # Assemble file
    args = [
        "rgbasm",
        "-p", "255",
        "-i", "source",
        "-i", "build/gfx/source",
        "-o", objPath,
        "-M", depPath,
        srcPath,
    ]
    print(" ".join(escapeCli(args)))
    result = cmd.run(args, stdout=sys.stdout, stderr=sys.stderr)

    # Mark as error on fail
    return (objPath, result.returncode != 0)

def buildAsmFolder(path):
    totalDirs = []
    objects = []
    isError = False

    for root, dirs, files in os.walk(path):
        totalDirs += dirs
        for filename in files:
            newObject, error = buildAsmFile(os.path.join(root, filename))
            isError = isError or error
            if newObject is not None:
                objects.append(newObject)

    for dirname in totalDirs:
        newObjects, error = buildAsmFolder(os.path.join(root, dirname))
        isError = isError or error
        objects += newObjects
    
    return (objects, isError)

def build():
    # Convert graphics using rgbgfx
    print("\nRGBGFX build step...")
    error = buildGfxFolder("source")
    if error == True:
        os._exit(1)

    # Assemble source files with rgbasm
    print("\nRGBASM step...")
    (objects, error) = buildAsmFolder("source")
    if error == True:
        os._exit(1)

    # Link objects with rgblink
    print("\nRGBLINK step...")
    output = os.path.join("build", "build")
    args = ["rgblink", "-p", "255", "-m", output+".map", "-n", output+".sym", "-o", output+".gb"] + objects
    print(" ".join(escapeCli(args)))
    result = cmd.run(args, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode != 0:
        os._exit(1)

    # Fix ROM header using rgbfix
    print("\nRGBFIX step...")
    args = ["rgbfix", "-v", "-j", "-c", "-p", "255", "-t", "SUKKORE", "-m", "MBC1", output+".gb"]
    print(" ".join(escapeCli(args)))
    result = cmd.run(args, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode != 0:
        os._exit(1)

# Figure out what actions to do
for action in sys.argv[1:]:
    if action == "--rebuild":
        dirtyCheck = False

# Perform actions
build()
