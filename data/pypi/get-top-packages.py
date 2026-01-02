import json
import os
from pathlib import Path

import requests as r

save_path = Path(os.path.dirname(os.path.realpath(__file__))) / "data"

os.makedirs(save_path, exist_ok=True)

TOP_PACKAGES_REV = "ff9797d12431782d007fbb8a4d9784826dda9cab"

# For sorting
# Inspired by https://github.com/astral-sh/uv/blob/0.8.10/crates/uv-platform-tags
BDIST = 0
SDIST = 1

P_ANY = 0
P_MANYLINUX = 1
P_MANYLINUX1 = 2
P_MANYLINUX2010 = 3
P_MANYLINUX2014 = 4
P_LINUX = 5
P_MUSLLINUX = 6
P_MACOS = 7
P_WIN_AMD64 = 8
P_WIN32 = 9
P_WIN_ARM64 = 10
P_WIN_IA64 = 11
P_OTHER = 12

ARCH_X86_64 = 0
ARCH_X86 = 1
ARCH_AARCH64 = 2
ARCH_OTHER = 3

BF_UNIVERSAL = 0
BF_UNIVERSAL2 = 1
BF_X86_64 = 2
BF_ARM64 = 3
BF_I386 = 4
BF_INTEL = 5
BF_OTHER = 6

ABI_NONE = 0
ABI_ABI3 = 1
ABI_CPYTHON = 2
ABI_PYPY = 3
ABI_OTHER = 4

L_NONE = 0
L_PYTHON = 1
L_CPYTHON = 2
L_PYPY = 3
L_OTHER = 4


def get_top_packages():
    json_data = save_path / "top-pypi-packages.min.json"
    if json_data.exists():
        print("Using cached top packages list")
        with open(json_data, "r") as f:
            return json.load(f)["rows"]
    else:
        print("Downloading top packages list")
        res = r.get(
            f"https://github.com/hugovk/top-pypi-packages/raw/{TOP_PACKAGES_REV}/top-pypi-packages.min.json"
        )
        data = res.json()
        with open(json_data, "w") as f:
            json.dump(data, f)
        return data["rows"]


def parse_platform_tag(tag):
    if tag == "any":
        return (P_ANY,)
    if tag == "win32":
        return (P_WIN32,)
    if tag == "win_amd64":
        return (P_WIN_AMD64,)
    if tag == "win_arm64":
        return (P_WIN_ARM64,)
    if tag == "win_ia64":
        return (P_WIN_IA64,)

    if tag.startswith("manylinux_"):
        attrs = tag[len("manylinux_") :].split("_", maxsplit=2)
        major = int(attrs[0])
        minor = int(attrs[1])
        arch = parse_arch(attrs[2])
        return (P_MANYLINUX, arch, -major, -minor)
    if tag.startswith("manylinux1_"):
        arch = parse_arch(tag[len("manylinux1_") :])
        return (P_MANYLINUX1, arch)
    if tag.startswith("manylinux2010_"):
        arch = parse_arch(tag[len("manylinux2010_") :])
        return (P_MANYLINUX2010, arch)
    if tag.startswith("manylinux2014_"):
        arch = parse_arch(tag[len("manylinux2014_") :])
        return (P_MANYLINUX2014, arch)
    if tag.startswith("linux_"):
        arch = parse_arch(tag[len("linux_") :])
        return (P_LINUX, arch)
    if tag.startswith("musllinux_"):
        attrs = tag[len("musllinux_") :].split("_", maxsplit=2)
        major = int(attrs[0])
        minor = int(attrs[1])
        arch = parse_arch(attrs[2])
        return (P_MUSLLINUX, arch, -major, -minor)

    if tag.startswith("macosx_"):
        attrs = tag[len("macosx_") :].split("_", maxsplit=2)
        major = int(attrs[0])
        minor = int(attrs[1])
        bf = parse_binary_format(attrs[2])
        return (P_MACOS, -major, -minor, bf)

    return (P_OTHER,)


def parse_arch(tag):
    if tag == "x86_64" or tag == "amd64":
        return ARCH_X86_64
    if tag == "x86" or tag == "i386" or tag == "i686":
        return ARCH_X86
    if tag == "aarch64" or tag == "arm64":
        return ARCH_AARCH64
    return ARCH_OTHER


def parse_binary_format(tag):
    if tag == "arm64":
        return BF_ARM64
    if tag == "i386":
        return BF_I386
    if tag == "intel":
        return BF_INTEL
    if tag == "universal":
        return BF_UNIVERSAL
    if tag == "universal2":
        return BF_UNIVERSAL2
    if tag == "x86_64":
        return BF_X86_64
    return BF_OTHER


def parse_abi_tag(tag):
    if tag == "none":
        return (ABI_NONE,)
    if tag == "abi3":
        return (ABI_ABI3,)
    if tag.startswith("cp"):
        version = "".join(filter(str.isdigit, tag[2:]))
        major = int(version[0])
        minor = int(version[1:])
        gil = not tag.endswith("t")
        return (ABI_CPYTHON, -major, -minor, gil)
    if tag.startswith("pypy"):
        return (ABI_PYPY,)
    return (ABI_OTHER,)


def parse_language_tag(tag):
    if tag == "none":
        return (L_NONE,)
    if tag.startswith("py"):
        version = tag[2:]
        major = int(version[0])
        minor = int(version[1:]) if len(version) > 1 else 0
        return (L_PYTHON, -major, -minor)
    if tag.startswith("cp"):
        version = tag[2:]
        major = int(version[0])
        minor = int(version[1:])
        return (L_CPYTHON, -major, -minor)
    if tag.startswith("pp"):
        version = tag[2:]
        major = int(version[0])
        minor = int(version[1:])
        return (L_PYPY, -major, -minor)
    return (L_OTHER,)


def fetch_files(package):
    url = f"https://pypi.org/simple/{package}/"
    res = r.get(url, headers={"accept": "application/vnd.pypi.simple.v1+json"})
    data = res.json()
    files = data["files"]
    latest_version = data["versions"][-1]

    for file in files:
        filename = file["filename"]
        url = file["url"]
        is_wheel = filename.endswith(".whl")
        if not is_wheel:
            if filename.endswith(".tar.gz"):
                name = filename[: -len(".tar.gz")]
            elif filename.endswith(".tar.bz2"):
                name = filename[: -len(".tar.bz2")]
            elif filename.endswith(".tgz"):
                name = filename[: -len(".tgz")]
            elif filename.endswith(".zip"):
                name = filename[: -len(".zip")]
            else:
                continue
            if name.endswith(f"-{latest_version}"):
                yield {
                    "sort_key": (SDIST,),
                    "url": url,
                    "version": latest_version,
                    "filename": filename,
                }
            continue
        name_parts = filename[:-4].split("-")
        version = name_parts[1]
        if version != latest_version:
            continue
        if len(name_parts) == 5:
            buildtag = ""
            pytag = name_parts[2]
            abitag = name_parts[3]
            archtag = name_parts[4]
        elif len(name_parts) == 6:
            buildtag = name_parts[2]
            pytag = name_parts[3]
            abitag = name_parts[4]
            archtag = name_parts[5]
        else:
            assert False
        for lang_tag in pytag.split("."):
            for abi_tag in abitag.split("."):
                for platform_tag in archtag.split("."):
                    lang = parse_language_tag(lang_tag)
                    abi = parse_abi_tag(abi_tag)
                    platform = parse_platform_tag(platform_tag)
                    sort_key = (BDIST, platform, lang, abi, buildtag)
                    yield {
                        "sort_key": sort_key,
                        "url": url,
                        "version": latest_version,
                        "filename": filename,
                    }


top_packages = get_top_packages()

cached_packages = set()
blacklisted_packages = [
    "aaaaaaaaa",  # does not exist anymore
    "git-python",  # only provides an egg
    "pyairports",  # does not exist anymore
    "zhdate",  # sdist does not follow filename format
    "fsd",  # does not exist anymore
    "pyrouge",  # latest version does not contain any files
]

with open(save_path / "data.json", "a+") as f:
    f.seek(0)
    for line in f:
        data = json.loads(line)
        cached_packages.add(data["name"])

    if len(cached_packages) > 0:
        print(f"Resuming... {len(cached_packages)} packages already fetched")

    for pkg in top_packages:
        name = pkg["project"]
        downloads = pkg["download_count"]

        if name in cached_packages or name in blacklisted_packages:
            continue

        print(f"Fetching {name}")

        best_archive = sorted(fetch_files(name), key=lambda x: x["sort_key"])[0]
        data = {"name": name, "downloads": downloads, **best_archive}

        f.write(json.dumps(data) + "\n")


print("Finished!")
