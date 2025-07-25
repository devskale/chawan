# chaseccomp

chaseccomp is a simple BPF assembler for interfacing with seccomp.

Input files look something like:

```
# load syscall number
load nr
# check if it's exit_group
ifeq SYS_exit_group allow
# if not, die
ret kill
: allow
# else, allow
ret allow
```

It has labels, conditional jumps, and support for C identifiers. In
fact, C identifiers are just passed on to the C compiler.

It also has an "ifeqdef" statement, which wraps each "ifeq" in an
ifdef. This lets us use the same filters for all platforms - if it
doesn't support a syscall, its "allow" rule just doesn't get compiled
in.

Ideally, the filter should be constructed by sorting the syscalls in
order of usage frequency and then checking each syscall with ifeqdef.

Also note, the following statement is prepended to every filter, with an
automatically determined audit arch nr:

```
load arch
ifne {audit arch nr of computer} deny
```

The assembler runs in three steps:

* gen_defs generates a C file from `$<.chasc` (and any chasc file it
  includes)
* The C file is compiled and executed, thereby disabling filters for
  syscalls that do not apply to this platform, and determining the audit
  arch number. The output is in `$<.chasc.expanded`.
* gen_syscalls takes `$<.chasc.expanded` and outputs `chasc_$<.h`.
  This is the final header file we include in the actual program.
