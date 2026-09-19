# Porting notes from docker_r_jupiter

Written 2026-09-19, after hardening `docker_r_jupiter`. Everything below was
verified by building and running images, not inferred from reading code. The
point of this file is that the same investigation does not have to happen twice.

**Status: implemented.** The §2 fixes below have been ported into this repo's
`Dockerfile`, `docker-bake.hcl`, and `scripts/` (2026-09-19). §3 ("Traps") is
kept as reference for future maintenance — e.g. if V8 is ever needed here, or
if INLA/Quarto versions drift between this repo and `docker_verse_mod` again.

---

## 1. Where this project sits

Three separate image lineages. Confusing them costs hours, so start here:

```
rocker-versioned2 → docker_verse     → jjserver/verse:<R>       (arm64+amd64, NO INLA)
                                          ├→ docker_r_jupiter  → jjserver/r_jupyterhub-<R>
                                          └→ docker_r_analysis → jjserver/r_analysis-<R>   ← this repo
rocker/verse      → docker_verse_mod → jjserver/verse_mod-<R>   (amd64 ONLY, has INLA+Quarto)
```

This repo builds **from `jjserver/verse`**, not from `verse_mod`. The Dockerfile
says `ARG NAMESPACE_FROM=rocker`, but `build_image.sh:14` overrides it to
`jjserver`, which is what actually gets used. Fixing something in `verse_mod`
does not affect this image, and `verse_mod` is amd64-only so it cannot be a base
for the arm64 builds `build_image.sh:82` produces.

**The R/Quarto/INLA version matrix lives in `docker_verse_mod/docker-bake.hcl`**,
a different repo with no git history. That is the only place the intended
version pairings are written down.

---

## 2. Fixes to port

Ranked by how much they matter. Each one is already implemented and verified in
`docker_r_jupiter` — copy from there rather than rewriting.

### 2.1 INLA is unpinned, and the comment about it is wrong

`Dockerfile:47-49`:

```r
# INLA repo added for its pre-built amd64/arm64 binaries
pak::repo_add(INLA = 'https://inla.r-inla-download.org/R/stable')
pak::pkg_install(c('renv', 'INLA', ...))
```

Three problems in three lines:

1. **The comment is false.** INLA publishes no arm64 Linux binary. The R package
   installs fine on arm64 but ships an x86-only `inla` binary, so it fails at
   run time. `docker_r_jupiter` compiles it from source on arm64 for exactly
   this reason, and `build_image.sh:82` builds `linux/arm64` here too.
2. **The version is not pinned**, so the package resolves to whatever is current
   on build day. This is what broke r_jupiter: a June build got package 26.6.8
   against a binary pinned at 26.06.08 and worked *by luck*; a September rebuild
   got 26.8.22 against the same binary and aborted with
   `Unused entry [INLA.stiles!tile.type]` — `inla_build` treats unrecognised
   Model.ini keys as fatal. **The R package and the binary must be the same
   version.** R version is irrelevant; the failure tracks the build date.
3. **The `stable` repo keeps only a sparse curated subset.** Pinned versions
   mostly resolve against `testing`, which retains the full archive (83
   releases as of writing).

Working recipe — see `docker_r_jupiter/scripts/install_inla.sh`. Note pak's
version syntax does **not** work against this repo (`INLA@26.08.07` and
`INLA@26.8.7` both fail with a spurious dependency conflict). Use the tarball
URL, and drive both halves from one variable:

```bash
pak::pkg_install("url::${INLA_REPO}/src/contrib/INLA_${INLA_VERSION}.tar.gz")
```

The zero-padded form (`26.08.07`) matches both the tarball name and the git tag
`Version_26.08.07`, so one value pins the package and the compiled binary.

### 2.2 No Ubuntu security patches

There is no `apt-get upgrade` layer here. `docker_verse` and `docker_verse_mod`
both have one; this repo and r_jupiter did not.

Inheriting patches from the base is **not** enough: the base carries the patches
that existed when *it* was built, and this image is rebuilt far more often. Every
fix published in between is missing. Add, immediately after `FROM`, before
anything else is installed so it only touches base packages:

```dockerfile
RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
```

Verified in r_jupiter: `apt-get -s upgrade` reports 0 pending afterwards.

### 2.3 R packages are not pinned to a date

The base points `repos` at `https://p3m.dev/cran/__linux__/noble/latest`, so
every rebuild resolves every R package to whatever is current that day. Same
class of bug as 2.1, applied to the whole package set at once.

Fix: a dated Posit (P3M) snapshot, one per R version. See
`docker_r_jupiter/scripts/set_cran_snapshot.sh`. Choosing the date: a recent one
for the R version that is current; for a superseded one, the day before its
successor was released, so the package set matches that R version's era.

Proven effective: the same Dockerfile yields `terra` 1.9.34 / `sf` 1.1.1 with a
2026-06-23 snapshot and `terra` 1.9.50 / `sf` 1.1.3 with 2026-09-19.

**Do not overwrite `Rprofile.site` wholesale.** Its other lines set
`HTTPUserAgent`, which is what makes P3M serve prebuilt binaries instead of
source. Replacing the file silently turns every install into a source build.
Rewrite only the URL with `sed`.

Setting it in `Rprofile.site` (not just an env var) makes the pin apply to every
R session in the container, for any user, even with no environment variables at
all. Two things bypass it by design: `R --vanilla`, and `renv`, which uses the
repos in a project's lockfile.

### 2.4 Quarto is not pinned

This image inherits whatever Quarto the base bundles, which drifts on every base
rebuild and changes rendered output — which defeats pinning R in the first
place. `docker_verse_mod` pins it; this repo and r_jupiter did not.

See `docker_r_jupiter/scripts/install_quarto.sh`. Quarto publishes both
`linux-amd64` and `linux-arm64` debs under the same release tag, and
`dpkg --print-architecture` matches Quarto's naming exactly.

### 2.5 Geographic packages are missing

System libraries are already complete here (`libgdal-dev`, `libgeos-dev`,
`libproj-dev`, `libudunits2-dev` at `Dockerfile:11-15`). What is missing are R
packages.

**Do not trust `verse_mod`'s comment** that "sf/terra/sp/spdep already ship with
rocker/verse". That is not true of the `jjserver/verse` lineage this repo builds
on. Verified in a built image: `sf` and `sp` present; `terra`, `spdep`, `stars`,
`raster`, `gstat`, `ncdf4` all absent.

The list settled on in r_jupiter: `terra`, `spdep`, `stars`, `raster`, `gstat`,
`ncdf4`. `ncdf4` also needs `libnetcdf-dev`, which is not in the base.

### 2.6 Versions have no single home

`ARG R_VERSION` in the Dockerfile is the only pin, and `build_image.sh` carries
its own defaults. r_jupiter moved everything into a `docker-bake.hcl` with one
target per R version, which also makes it trivial to rebuild an old R version
for security patches without editing or committing anything.

If you copy that pattern, note the mistake made there: a drift check comparing
bake against the Dockerfile's `ARG` defaults **cannot pass for more than one
target**, because the Dockerfile only holds one set of values. Bake always
overrides those defaults anyway, so the check is only meaningful for the default
target.

---

## 3. Traps

Things that look like fixes and are not. Each of these cost real time.

### `R_ext/PrtUtil.h` is missing — do NOT copy it back

R 4.6 deliberately removed `PrtUtil.h` and added `ObjectTable.h`. Both R 4.5.1
and R 4.6.1 ship exactly 34 headers in `R_ext/`, which is what makes it look
like a broken `make install`. It is not: the R installation is fine.

Copying the header back from the R source tarball re-exposes an API R Core
withdrew, letting old packages compile against symbols the R binary no longer
exports — which is how you get `undefined symbol: SETLENGTH` at load time.

Packages that fail this way (`data.table`, `Rcpp`, `rlang`, `cpp11`, …) are
**old pinned versions in a project's `renv.lock`**, not an image problem. Fix
them in the project with `renv::install(...)` + `renv::snapshot()`.

The toolchain here is healthy — verified by source-compiling `yaml` 2.3.12,
`Rcpp` 1.1.2, and `TMB` 1.9.25, the last of which compiled a C++ template model
and fitted it (convergence 0).

### Same package version ≠ same binary

The sharpest surprise of the day. `V8` 8.2.0 is 8.2.0 in both the June and
September snapshots, but P3M **recompiled it in between**: the June build links
`libnode.so.109`, the September build bundles the engine. Pinning the version is
not enough — the snapshot determines the artifact.

Practical consequence: never assume a shared-library dependency is absent
because you checked once. Detect it. r_jupiter's `install_v8.sh` runs `ldd` on
the installed `.so`, derives the package name from whatever soname is missing
(`libnode.so.109` → `libnode109`), and supplies it only if needed.

### Never hardcode a versioned package name

`libnode109`, `libicu74` and friends exist in exactly one Ubuntu release. Hard
coding one breaks the build on the next Ubuntu while fixing nothing. Use stable
names (`libgdal-dev`, `libnetcdf-dev`) or derive the versioned one at runtime.

### The NodeSource conflict does not apply here

A note in r_jupiter described a conflict between NodeSource's nodejs 20 and
Ubuntu's `libnode109` (via `node-acorn` → `nodejs:any`). **This repo installs no
Node at all** — zero mentions in the Dockerfile — because it has no JupyterHub
and therefore no `configurable-http-proxy`. If V8 is ever needed here,
`apt-get install libnode109` should just work, with no `.deb` extraction and no
`PKG_SYSREQS=false`. Verify before assuming, but do not port that workaround
blindly.

---

## 4. Open questions specific to this repo

- **Is `ARG R_VERSION=4.4.3` current?** The most recent local image is
  `jjserver/r_analysis-4_5_1:1` (R 4.5.1), so the Dockerfile default and reality
  have already diverged.
- **That image has almost nothing installed.** Checked 2026-09-19: of
  `renv, repana, quarto, targets, tarchetypes, INLA`, only `renv` is present,
  out of 211 packages total. Either it predates `Dockerfile:48-49` or that layer
  partially failed. Worth a rebuild and a look before trusting it.
- **texlive differs across the three repos.** `verse_mod` installs 13
  `texlive-*` packages including `texlive-fonts-extra`; this repo and r_jupiter
  install 10 without it. A `.tex` that renders on the HPC image can fail here
  over `inconsolata.sty`. Decide whether that gap is intentional.
- **`NAMESPACE_FROM=rocker` as the Dockerfile default is misleading**, since
  every real build overrides it to `jjserver`. `rocker/verse` is amd64-only, so
  the default would break the arm64 half of the build if anyone used it.
