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

def assembleFile(srcPath):
    srcName, srcExt = os.path.splitext(srcPath)
    if srcExt != ".asm":
        return (None, False)

    objPath = os.path.join("build", "obj", srcName) + ".o"

    # Ignore file if object is newer
    if os.path.exists(objPath):
        objTime = os.path.getmtime(objPath)
        srcTime = os.path.getmtime(srcPath)
        if objTime >= srcTime and dirtyCheck:
            return (objPath, False)

    # Assemble file
    os.makedirs(os.path.dirname(objPath), exist_ok=True)
    args = ["rgbasm", "-p", "255", "-i", "source", "-o", objPath, srcPath]
    print(" ".join(escapeCli(args)))
    result = cmd.run(args, stdout=sys.stdout, stderr=sys.stderr)

    # Mark as error on fail
    return (objPath, result.returncode != 0)

def assembleFolder(path):
    totalDirs = []
    objects = []
    isError = False

    for root, dirs, files in os.walk(path):
        totalDirs += dirs
        for filename in files:
            newObject, error = assembleFile(os.path.join(root, filename))
            isError = isError or error
            if newObject is not None:
                objects.append(newObject)

    for dirname in totalDirs:
        newObjects, error = assembleFolder(os.path.join(root, dirname))
        isError = isError or error
        objects += newObjects
    
    return (objects, isError)

def build():
    # Assemble source files with rgbasm
    (objects, error) = assembleFolder("source")
    if error == True:
        os._exit(1)

    # Link objects with rgblink
    output = os.path.join("build", "build")
    args = ["rgblink", "-p", "255", "-m", output+".map", "-n", output+".sym", "-o", output+".gb"] + objects
    print(" ".join(escapeCli(args)))
    result = cmd.run(args, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode != 0:
        os._exit(1)

    # Fix ROM header using rgbfix
    args = ["rgbfix", "-v", "-j", "-c", "-p", "255", "-t", "PROJECT", "-m", "MBC1", output+".gb"]
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
