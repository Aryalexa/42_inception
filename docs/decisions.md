
# Decisions

## Decision 1: Alpine vs Debian

From proj-requirements.md: "penultimate stable version of Alpine or Debian" — your choice.

Alpine (chosen here):

 - ✅ Tiny (~5MB base vs ~100MB for Debian)
 - ✅ Faster build/push/pull
 - ✅ Smaller attack surface
 - ✅ Docker standard (most images use Alpine)
 - ❌ Uses musl libc instead of glibc (can cause compatibility issues with some apps)
 - ❌ Fewer packages, fewer docs

Debian:

 - ✅ More packages, better compatibility
 - ✅ glibc (standard C library)
 - ❌ Much larger, slower
 - ❌ More bloat for a container

For this project: Alpine is fine, but if MariaDB has issues, switching to Debian is easy. Let's test MariaDB first and see.