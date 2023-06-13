using BinaryBuilder, Pkg
using Base.BinaryPlatforms: arch, os

const YGGDRASIL_DIR = "../.."
include(joinpath(YGGDRASIL_DIR, "fancy_toys.jl"))
include(joinpath(YGGDRASIL_DIR, "platforms", "cuda.jl"))

name = "CUDNN"
version = v"8.9.2"

script = raw"""
mkdir -p ${libdir} ${prefix}/include

cd ${WORKSPACE}/srcdir
if [[ ${target} == *-linux-gnu ]]; then
    cd cudnn*
    find .

    install_license LICENSE

    mv lib/libcudnn*.so* ${libdir}
    mv include/* ${prefix}/include
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    cd cudnn*
    find .

    install_license LICENSE

    mv bin/cudnn*64_*.dll ${libdir}
    mv include/* ${prefix}/include

    mv ../dll_x64/zlibwapi.dll ${libdir}

    # fixup
    chmod +x ${libdir}/*.dll
fi
"""

augment_platform_block = CUDA.augment

products = [
    LibraryProduct(["libcudnn_ops_infer", "cudnn_ops_infer64_$(version.major)"], :libcudnn_ops_infer64),
    LibraryProduct(["libcudnn_ops_train", "cudnn_ops_train64_$(version.major)"], :libcudnn_ops_train64),
    LibraryProduct(["libcudnn_cnn_infer", "cudnn_cnn_infer64_$(version.major)"], :libcudnn_cnn_infer64),
    LibraryProduct(["libcudnn_cnn_train", "cudnn_cnn_train64_$(version.major)"], :libcudnn_cnn_train64),
    LibraryProduct(["libcudnn_adv_infer", "cudnn_adv_infer64_$(version.major)"], :libcudnn_adv_infer64),
    LibraryProduct(["libcudnn_adv_train", "cudnn_adv_train64_$(version.major)"], :libcudnn_adv_train64),

    # shim layer
    LibraryProduct(["libcudnn", "cudnn64_$(version.major)"], :libcudnn),
]

dependencies = [RuntimeDependency(PackageSpec(name="CUDA_Runtime_jll"))]

builds = ["11", "12"]
for build in builds
    include("build_$(build).jl")
    cuda_version = VersionNumber(build)

    for (platform, sources) in platforms_and_sources
        augmented_platform = Platform(arch(platform), os(platform);
                                      cuda=CUDA.platform(cuda_version))
        should_build_platform(triplet(augmented_platform)) || continue
        if platform == Platform("x86_64", "windows")
            push!(sources,
                ArchiveSource("http://www.winimage.com/zLibDll/zlib123dllx64.zip",
                              "fd324c6923aa4f45a60413665e0b68bb34a7779d0861849e02d2711ff8efb9a4"))
        end
        build_tarballs(ARGS, name, version, sources, script, [augmented_platform],
                       products, dependencies; lazy_artifacts=true,
                       julia_compat="1.6", augment_platform_block,
                       dont_dlopen=true)
    end
end
