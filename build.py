import os
import subprocess as cmd
import sys

dirtyCheck = True 

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
    command = cmd.list2cmdline(["rgbasm", "-p", "255", "-i", "include", "-o", objPath, srcPath])
    print(command)
    result = cmd.run(
        command,
        stdout=sys.stdout,
        stderr=sys.stderr,
    )

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
    command = cmd.list2cmdline(["rgblink", "-p", "255", "-m", output+".map", "-n", output+".sym", "-o", output+".gb"] + objects)
    print(command)
    result = cmd.run(command, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode != 0:
        os._exit(1)

    # Fix ROM header using rgbfix
    command = cmd.list2cmdline(["rgbfix", "-v", "-j", "-c", "-p", "255", "-t", "PROJECT", "-m", "MBC1", output+".gb"])
    print(command)
    result = cmd.run(command, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode != 0:
        os._exit(1)

# Figure out what actions to do
for action in sys.argv[1:]:
    if action == "--rebuild":
        dirtyCheck = False

# Perform actions
build()
