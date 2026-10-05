---
title: "CLI & macOS Optimization Anti-Patterns"
domains:
  - "macOS XNU Kernel Architecture: Process Creation bottlenecks (fork vs posix_spawn)"
  - "Mach IPC and kqueue Limitations: Blocking I/O and message overhead"
  - "Memory Management Overhead: Page faults and COW on large memory allocations"
  - "Shell Engine & Initialization: Eager-loading and startup delays"
  - "Toolchain & Version Manager Overheads: Python/Node.js environment init"
  - "Terminal Emulator Architecture: GPU accel, single-instance modes"
  - "CLI History & Persistence: I/O blocking in history systems (e.g., Atuin)"
description: "Абсолютно сырые технические данные, полные дампы кода и бенчмарки для глубокого рефакторинга."
backlinks: ~/.config/fish/.meta/research/mcp_dump.json
---

# Сырые данные и антипаттерны для рефакторинга (Без абстракций)

Ниже представлена полная, не урезанная и не абстрактная информация из дампа исследования, разбитая по 7 предметным областям. Никакого перефразирования или саммаризации — только исходные тексты, логи, исходный код ядра и технические обсуждения.

## 1. macOS XNU Kernel Architecture (Process Creation, fork vs posix_spawn)

### Process creation overhead
**URL:** https://static.usenix.org/events/usenix04/tech/general/full_papers/ruan/ruan_html/node13.html

```text
### Process creation overhead 

 By recording all CPU time values, we find that the largest call times are for the 

 fork()

 system call and that its cost grows with the number of invocations, approaching 130 msec. Figure 5 shows the per-call time as a function of invocation. We observe that 

 fork()

 time increases as the program runs, starting as low as 0.3 msec. These calls stem from the SpecWeb99 workload's requirement that 0.15% of the requests be handled by forking new processes. 

 A full call trace indicates that 

 fork()

 spends the bulk of its time copying file descriptors and VM map entries (for mapped regions). Rather than changing the implementation of 

 fork()

, we opt to slightly modify the Flash architecture. We introduce a new helper process that is responsible for creating the CGI processes. Since this new process does not map files or cache open files, its 

 fork()

 time is not affected by the main process size. This change yields a 10% improvement, to 440 simultaneous connections and a 1.50GB dataset size. 

Figure
```

---

### A fork() in the road
**URL:** https://dl.acm.org/doi/10.1145/3317550.3321435

```text
The received wisdom suggests that Unix's unusual combination of fork() and exec() for process creation was an inspired design. In this paper, we argue that fork was a clever hack for machines and programs of the 1970s that has long outlived its usefulness and is now a liability. We catalog the ways in which fork is a terrible abstraction for the modern programmer to use, describe how it compromises OS implementations, and propose alternatives.
...
Mike Accetta, Robert Baron, William Bolosky, David Golub, Richard Rashid, Avadis Tevanian, and Michael Young. Mach: A new kernel foundation for UNIX development. In USENIX Summer Conference, pages 93--113, June 1986.
...
Casper Dik. posix\_spawn() as an actual system call. Oracle Solaris Blog, February 2018. URL https://blogs.oracle.com/solaris/posix\_spawn-as-an-actual-system-call.
...
, 1 (3):255--
```

---

### Userspace kernel server (darlingserver)
**URL:** https://github.com/darlinghq/darling/issues/1093

```text
This is a tracking issue for the development of darlingserver, Darling's userspace kernel server, ... to Wine's wineserver. The goal of this project is to replace Darling's kernel module and have Darling run completely in userspace. This is currently being worked on in
...
As mentioned ... , darlingserver is ... userspace kernel server for Darling ... What it does ... that it provides services like Mach ... (among others) for all processes within a Darling container. These services require interaction and cooperation among all process in the container, therefore they must necessarily be provided by a "supervisor" process. 
 
## Why? 
 
The LKM has always been the biggest headache with developing and using Darling. Bugs there can be hard to track down and, when they occur, they can (and do) crash/freeze/panic the kernel. This is the reason why Darling currently should only be run in a VM. 
 
Moving the LKM's job into userspace resolves these issues: because darlingserver runs in userspace, it doesn't have the power to crash the kernel. Additionally, for the same reason, darlingserver makes "kernel" issues much easier to debug, since it's just a userspace process that can easily be debugged with LLDB or GDB. While Darling is and would still be experimental software even with darlingserver (and should therefore still only be used in a VM), much of the risk is eliminated with this approach. 
 
## When? 
 
My personal goal for darlingserver to be ready-to-merge is sometime around April 2022. A basic shell should be working sometime in February 2022. These are not hard deadlines, however. 
 
## How? 
 
I will be keeping track of how significant aspects of darlingserver are implemented by adding comments in this issue. This information can later be added to Darling's documentation of its internals, when/if darlingserver is merged. 
 
## Roadmap 
 
As issues/missing parts are discovered, they will be added here. 
 
 - [x] `kqueue` support 
 - Bring back and update libkqueue 
 - [x] `psynch` support 
 - Investigate using pthread kext code in darlingserver, with some additional glue/duct-tape code
...
> ### Mach IPC and similar XNU services
> **Alternate title**: "Threading in darlingserver".
> 
> The approach taken here is the same as the LKM: import XNU's code and provide glue/duct-tape code to allow it to work in a different environment. However, it works very differently from the LKM.
> 
> XNU's code expects to be able to sleep on a thread while waiting for something (like a semaphore or a Mach message). In the LKM, this is relatively simple to do because we're running the context of the thread we're operating on. However, in darlingserver, we're in a separate process with its own threads; the managed threads are put to sleep while darlingserver hasn't responded to their RPC calls (they sleep on `recvmsg`).
> 
> Now, the issue is that waiting normally (e.g. with a futex) in darlingserver whenever XNU code wants to wait would quickly cause issues. We either need a real thread in darlingserver for each managed thread (which would waste system resources) or we need to have microthreads (a.k.a. fibers) with a limited number of actual threads running them. The current implementation chooses the second approach, as it avoids the overhead of having numerous actual threads.
> 
> The way this works is that for each managed thread darlingserver has, it creates a microthread context. This consists of some stack space (16KiB at the moment) as well as information XNU's code needs to keep track of. When darlingserver receives an RPC call from a managed thread, it schedules the corresponding microthread to run on a worker thread (of which there are a minimum of 2 and a maximum of however many logical cores are on the host machine). Once the microthread gets a chance to run, it processes the call however it needs to. In many cases, it will call out to some XNU code that performs the necessary work.
> 
> Many times, microthreads run to completion in one run; once they finish, they return control to the worker thread and it continues running other microthreads. Sometimes, though, the XNU code tries to suspend the current thread (to wait for something); when this happens, the microthread state is saved and it then returns control to the worker thread. The worker thread then picks another microthread to run and continues working.
...
> Ok, so the `poll` issue turned out to be a case of libkqueue misbehaving and closing descriptors when it shouldn't. Unfortunately, it appears that the other bug Mio surfaced is still present (that the last test appears to hang when it actually doesn't).
> 
> Also, I'm not entirely sure why, but the LLDB issue with `run` seems to have disappeared (before my changes) :man_shrugging:.
...
> The Mio test hang bug and MyOpenGL freeze bug actually turned out to be the same thing: we were scheduling duct-tape timers incorrectly.
> 
> Here's what was happening: XNU's timer_call code calls `timer_queue_assign` to inform the architecture-specific timer code about a new deadline and have it pick a timer queue. We were always updating the timer with the deadline given, which in some cases was much later than the current deadline. As such, all other timers were delayed until that timer fired.
> 
> The fix was simple: just ignore the new deadline if it's later than the current deadline.
```

---


## 2. Mach IPC and kqueue Limitations

### The cost of IPC: an architectural analysis
**URL:** https://www.researchgate.net/publication/228959784_The_cost_of_IPC_an_architectural_analysis

```text
Moreover, Mac OS X is based on the Machµ-kernel, which
...
some perforamance critical device drivers, as the
disk ones, inside the kernel space [18].
...
tions [4].µ-kernel based operating systems, such as Mach [1],
...
Long-messages require the kernel to copy data from mem-
...
address space. Inµ-kernels such as Mach, this process requires
copying the data to a kernel buffer, then perform an address
space switch and, ﬁnally, copying the data from within the
...
To avoid this intermediate
...
The only noticeable overhead of our measurements is in-
```

---

### Evolving Mach 3.0 to a Migrating Thread Model
**URL:** https://www.usenix.org/legacy/publications/library/proceedings/sf94/full_papers/ford.pdf

```text
be queued to the port. This is not ideal, and we plan to detect when the last available activation is about to be used for a migrating RPC, and instead of immediately making the requested RPC, temporarily \sidetrack" and make a special noti cation upcall into the server. At
...
Server Thread Management The cthreads library presents a signi cant problem to the server of a 
migrating RPC. Servers use cthreads to multiplex user threads on top of kernel threads, replacing kernel 
mode context switches with much faster user-level context switches, whenever possible. However, one of the 
main assumptions made by the user-level threads package is that all of the kernel threads on which it is 
running its user-level threads are interchangeable|that one kernel thread can be used for an operation just 
as well as another. This assumption can be satis ed in a static thread model, although in the process it 
makes real-time monitoring and control of server threads di cult. 
In a migrating thread model, however, kernel threads migrating in from clients are not interchangeable| 
they may have di erent priorities and other attributes. Even ignoring this, the return-to-kernel after an 
RPC has been processed must be done on the same kernel thread that the RPC came in on. In general, 
trying to multiplex threads in this manner loses one of the main advantages of our design: providing a kernel 
7
...
entity (the activation stack) which represents a particular piece of work in progress, i.e., an entire logical 
thread of control. Therefore, multiplexing a server's user-level threads on top of incoming kernel threads is 
not appropriate. In cthreads, multiplexing can easily be avoided by \wiring" the user-level thread. 
However, some speed is lost in the elimination of user-level thread multiplexing, because synchronization 
operations in the server sometimes now require kernel-level context switches instead of user-level context 
switches. Measuring real applications, including on multiprocessors, will be necessary before we can be 
sure the gains from better RPC performance are not outweighed by this additional cost. We believe that 
the speed advantage of user-level context switching is not as signi cant in typical RPC servers as it is in 
compute-intensive applications, which are the traditional benchmarks for thread implementations. In well 
designed servers providing \system" functions, we suspect that internal contention can be minimized so 
that the importance of RPC speed outweighs that of context switch speed. We point out that in many 
commercial microkernel-based systems, including QNX[20], Chorus[26], and KeyKOS[6], OS servers do not 
generally multiplex user-level threads over multiple kernel threads. Instead, these systems either provide 
multithreading purely with kernel threads, or their functions are su ciently decomposed so that each server 
can be based on a single kernel thread, requiring no internal synchronization. However, until there is more 
extensive performance analysis of servers using migrating RPC, losing user-level threads when servicing 
RPCs remains a concern. 
Note that it is only for \guest" threads migrating in from other tasks that user-level thread multiplexing 
is a problem; threads native to the server can still use some kind of user-level thread system, or even a 
specialized multiplexing mechanism such as scheduler activations.
...
costs. We observe that the percentage improvements in instruction count and memory operations are ap 
proximately equal for each stage of RPC. This suggests that instruction count is a valid measure of the 
relative contribution of each stage to the overall performance gain. 
Examination of the context switch code in the old optimized RPC path explains much of its cost: the 
kernel essentially executes a portion of the scheduler specially hand-coded inline. Numerous constraints 
must be satis ed: both old and new threads must be in just the right states, run and wait queues must 
be maintained correctly, locks on ports, threads, IPC spaces, and other data structures must be taken and 
released in the right order to avoid deadlocks; timers are manipulated; interrupt levels are changed; resources 
acquired along the way must be carefully tracked to ensure that it will be possible to unroll everything if, 
for some reason, the computation falls o the optimized path. 
Table 2 shows the instruction mix for each path, broken into three categories: total instructions, 
loads/stores, and branches. The migrating path has a somewhat higher percentage of loads and stores 
(56% vs. 43%), presumably due to the fact that the basic memory-intensive aspects of IPC|register saving 
and restoring, memory copying, and data structure traversal|are less obscured by computational overhead. 
The relative incidence of branch instructions is much lower, however (10% vs. 17%). This, along with 
the ninefold reduction in total number of branch instructions, re ects the lower logical complexity of the 
migrating path.
...
8.4 Micro and Macro Benchmark Results 
Measurements of the costs of cross-task migrating and traditional switching RPC are presented in Table 3. 
The columns on the left include only the kernel costs of RPC, while the ones on the right include both kernel 
and user (marshaling) costs, obtained in another set of runs. On this machine, a null local RPC now spends 
less than 10 microseconds in the kernel. The speedup from migrating threads varies with parameter size 
from a factor of 3.4 for null RPC, a factor of 2.0 for 1K of data, to a factor of 1.7 for long in-line marshaled 
data. This factor of 1.7 comes from the fact that the data is copied three times in the switching path|once 
during marshaling and twice in the kernel|but only twice on the complete migrating path. 
One interesting observation is that the number of cycles per instruction (CPI) is considerably worse on 
the migrating path (3:0 = 648=213) than on the original path (2:1 = 2318=1128). We believe that some or 
all of this is due to two factors: the higher percentage of load/store instructions as described above, and 
the fact that the instructions on the hand-coded migrating path were not carefully scheduled and optimized 
like the C compiler did to most of the old path. Therefore, more careful coding of the migrating RPC path 
could somewhat lower CPI. More investigation of the CPI di erence is warranted.
...
The measurement of the kernel time for 32K migrating RPC showed severe side e ects of the HP730's direct-mapped cache. At the top is our original measurement, a suspiciously low time resulting in a rather unbelievable 4:0 speed improvement. Below it is the same measurement taken after shifting the message bu ers slightly so that the cache lines would con ict, resulting in an improvement of 1:6 , below the factor of two we would expect due to the data being copied once instead of twice. This demonstrates the importance of cache e ects in data transfer, and deserves further investigation in the future. As a preliminary test of overall performance impact, we measured the time for a \make" of the gas assembler. Under migrating threads, the elapsed time went from 109 to 107 seconds, an improvement of about 2%. The link phase took about 3 seconds. A link of a larger program (the HP linker itself ), improved from 14 seconds to 12 seconds, an improvement of 14%. We believe this greater improvement is due to ld having a higher ratio of system calls to computation. One area where we slow down is in RPCs to the kernel. These do not currently migrate since we haven't changed the kernel to provide activations on its ports. We do not expect doing so to be di cult. When that is done, all messages which originally would have used the optimized path (true RPCs), should be migrating. We expect a tuned implementation to achieve more overall speedup, and if other RPC optimizations enabled by migrating threads are performed, signi cantly more speedup.
```

---

### [2008.02145] Interprocess Communication in FreeBSD 11: Performance Analysis
**URL:** https://ar5iv.labs.arxiv.org/html/2008.02145

```text
The heart of our investigation of the hypothesis set was an I/O benchmark program written by Robert N.M. Watson. The benchmark is able to measure IPC across both threads and processes via either pipes or sockets: the corresponding POSIX APIs are pthread_create, fork, pipe, and socketpair respectively. For sockets, the kernel’s internal buffer size can be changed using setsockopt; the benchmark exposes this via the -s flag, setting it to be the same size as the userspace buffers. In addition to recording the effective IPC bandwidth seen using a particular configuration it enabled CPU performance counters (PMCs) to be queried to further enlighten our understanding of the system’s behaviour. To guarantee that read and write performed full, not partial, operations, the system was configured to increase its kern.ipc.maxsockbuf value to 32 MiB, greater than the largest buffer size tested against.
...
Figure 1 presents the results produced by the benchmark across a range of buffer sizes and using each of the three IPC mechanism configurations. The -s qualifier denotes that the size of the kernel buffer was modified to mirror the size of the user space buffers. From first impressions there is a clear trend in the data: regardless of the IPC model, performance increases with buffer sizes up to a point ($∼similar-to\sim$ 32 to 64 KiB), after which it begins to decrease substantially. The initial increase in performance can fairly easily be attributed to a decrease in the number of read() syscalls given the total I/O size is fixed. This behaviour is directly in line with the high-level conceptual model presented in Hypothesis 1. Figure 1 however contains a number of inflections points hinting at more subtle effects at play. To decipher this we will now consider each IPC mechanism in greater depth using DTrace and direct source code analysis.
...
The greatest observed throughput for pipe occurred with a buufer size of 64 KiB, as can be clearly seen in Figure 1. A contributing factor towards this is pipe’s resizing mechanism, 5 5 5 Refer to kern/sys_pipe.c, lines 1079-1088. which, if enabled, 6 6 6 It is on our system (sysctl kern.ipc.piperesizeallowed $→→\rightarrow$ 1). will increase the default PIPE_SIZE from 16 KiB to a maximum of BIG_PIPE_SIZE (64 KiB) in increments. This is visible via DTrace’s syscall::read*:entry/return probes, which clearly showed all buffer sizes beyond 64 KiB resolving to 256 read() calls of size 64 KiB.
...
The implementation of socketpair is far more complicated than that of pipe, something that is rather unsurprising given how versatile the POSIX standard forces it to be. Notes in kern/uipc_socket.c and kern/uipc_usrreq.c enlighten a handful of the difficulties faced, especially in the face of ’ancillary data’; credentials, file descriptors, and even, one layer deeper, other sockets themselves may potentially be passed over a socket, requiring additional considerations such as a specialised garbage collector for dead sockets. Importantly, FreeBSD’s implementation does not lend itself towards interoperability between local sockets and shared memory (or other VM optimisations); this is undoubtedly key to its poorer performance when compared to pipe in Figure 1.
...
to one another after the 8 KiB mark. This was initially investigated using the DTrace syscall::read*/write*:entry/return probes. All buffer sizes larger than 8 KiB resolved to 2048 read() calls of 8 KiB when the -s flag was not used, explaining its early plateau in Figure 1. This limitation was not observed when the -s flag was used.
...
Both ($γ𝛾\gamma$) and ($δ𝛿\delta$) depict the high watermark, or maximum char count supported, of the sockbuf 8 8 8 http://fxr.watson.org/fxr/source/sys/sockbuf.h?v=FREEBSD-11-0 buffer structures used for both sending and receiving sockets. Given that 0x2000 = 8 KiB this is a highly plausible explanation for the plateau in socketpair performance between 8 KiB and 64 KiB. The -s flag manually sets the high and low watermarks (int sb_lowat) to the size of the benchmark’s buffer; this was verified using the same DTrace probe.
...
Figure 2(a) depicts the mem PMC counter’s MEM_READ attribute; this can be used to give an approximate indicator of the number architectural read operations. Frustratingly this cannot be directly translated into the number of bytes read. This is, we believe, due to specialised ARM instructions such as LDRD, which loads from two locations simultaneously in one operation — LDRD is used at various points in FreeBSD’s ARM implementation, including memcpy. 9 9 9 Refer to contrib/cortex-strings/src/arm/memcpy.S However from this we are able to very clearly pick out the point at which socketpair with and without the -s flag deviates (8 KiB), reaffirming the behaviour reported by DTrace. As the number of architectural reads directly translates as I/O load on the system, lower values are better. The VM optimisations of the pipe implementation found in the FreeBSD source can be seen coming into play, with a far lower impact in hardware. Additionally, other inflection points can also be seen; socketpair with the -s flag plateaus at 32-64 KiB, and pipe at 64 KiB, mirroring the story told by the bandwidth readings reported in Figure 1. MEM_READ has shown itself to be a fairly reliable proxy for bandwidth performance at lower buffer sizes, especially as it reliably exposes software behaviours, encapsulating the bare-metal requests exiting the kernel.
...
A vital observation to make to explain the sharp drop in bandwidth performance is that as performance decreases in the 32-256 KiB buffer size range, both the number and relative expense of AXI operations increase drastically. Taking the readings observed for pipe as an example, and given no other PMC attributes reveal anything of particular note, it is highly likely that these observed behaviour on the AXI bus are direct indicators of the core issue causing performance to crash.

There is no L3 cache in the BeagleBone Black’s Cortex-A8 processor, making the L2 cache the last level of on-chip memory. Sadly the Cortex-A8 does not expose a PMC for measuring the number of L2 cache misses, but as a proxy Figure 2(d) plots the average clock cycles per L2 cache operation; this will implicitly expose the number of misses as operations take longer whilst fetching data from DRAM. We can see that this proxy L2 miss metric aligns almost exactly with the increased strain seen on the AXI bus, giving credence to the assertion that the observed performance collapse is directly caused by L2 cache exhaustion. This further explains why both the increase in load and decrease in performance cease to change so drastically when the marked L2 limit is hit; this is the first truly degenerate case as the working set no longer fits in the last-level cache. For this reason it is clear to see how this impacts all IPC mechanisms in roughly the same way.
...
Increasing buffer sizes improves performance for all IPC mechanisms up to a point ($∼similar-to\sim$ 32-64 KiB), after which it degrades. Thus the optimal cache size depends on a wide range of factors, but overhead amortisation is fundamentally in contention with the cache performance as buffers grow larger. Hypothesis 1 can therefore be soundly accepted.
...
Pipes yield better performance than sockets for local communication due to specific memory optimisations. Further, sockets are inherently constrained by their versatile design and independent in-kernel buffer, adding up to a far less scalable IPC solution. Virtual memory optimisations for pipe vastly decrease the expense of performing operations, as shown in Figure 2(a), for example — this indicates a far more scalable solution for local IPC than socketpair. Hypothesis 2 is also accepted confidently, citing evidence from FreeBSD’s source code and observed PMC attribute results to assert that VM-optimisations were a major component of pipe’s speed.
```

---

### Mach based OS X Interprocess Communication (Obsolete)
**URL:** https://www.chromium.org/developers/design-documents/os-x-interprocess-communication/

```text
==Current status of this design:== The design described here is currently not used on OS X. Please see the Interprocess Communication design doc for coverage of the current implementation for all platforms. A reference implementation of Mach based IPC including a kqueue bridge can be ... in issue 5308.

In 2015, another consideration was given to using Mach IPC, and the results of that survey are here. ==Rationale for not using Mach based IPC:== Chrome handles network communication and IPC messages on the same thread. Sockets are waited on using kqueues via libevent. Although there is a constant defined in the kqueue headers on OS X (EVFILTER_MACH in sys/event.h), there is currently no way to block on both a socket and a mach port at once, this means that our only option is to spawn another thread to bridge Mach messages to kqueue. Our reference implementation does this by opening a pipe between both threads and writing a byte each time a Mach message is received. Because of this extra step, we now need to pay the price both of receiving a Mach message and communicating via a pipe between threads. We've timed this approach and found it to be 10uSec slower on Desktops & 20uSecs faster on laptops than a pure pipe based implementation. If you look at the measurements at the bottom of this document, you can see that most of the messages Chrome sends are very small. So the performance benefits of Mach messages over pipes are negligible. Thus our decision at this time is to use the same approach as Linux. If we run into problems at a later date with a pipe-based implementation we can revert to the Mach-based one.
...
Mach ports have a fixed queue size, we want to be able to send arbitrary numbers of messages without blocking.

Messages to send over the wire are queued up on the Server side in an std::vector<Message*>, we specify a timeout value when sending a Mach message, if the send times out then we set a delayed task to attempt to resend the message after a delta.

When IPC::Channel::Send ... called, we attempt to send out
...
What follows are the results of some benchmarks we ran contrasting Mach messaging and FIFO's. We tested Mach ports using both inline & out of line (OOL) data transfer. Inline transfer means the payload is transferred as part of the message and copied into the receiving process. OOL remaps the memory area using copy-on-write semantics.

The executive summary is that Mach messages are faster than FIFOs on OS X, especially if we transfer messages larger than a certain threshold using OOL.
...
Our testing methodology was to send over 2000 messages, times are in uSec and the ones shown represent the 98th percentile of the measured data. Variance of all values is ~10uSec, possibly higher. ==Discussion:==

Inline Mach messages take a performance hit for message sizes >5K, below that they are ~1.5X FIFOS on a 4 core Mac desktop and 280%-1000% faster than FIFOs a Laptop.

The desktop/laptop difference is something we see consistently. OOL transfer has a constant overhead of ~30uSec which appears to be a clear win over any method that copies data between processes.

==The data (times in uSec +/- 10uSec):== Laptop: Packet Size (bytes) Mach Mach OOL FIFO % min(Mach,Mach OOL) better than FIFO 100 29 35 112 386 200 10 37 121 1210 500 11 36 124 1127 1024 9 36 115 1277 2048 28 37 131 467 3072 11 39 129 1172 4096 11 29 128 1163 5120 13 31 127 976 6144 51 30 134 446 7168 46 30 133 443 8192 51 32 215 671 9216 57 30 218 726 1048576 1477 29 2873 9906 5242880 11079 39 10924 28010 7340032 15144 38 14184 37326 Desktop:

Packet Size (bytes) Mach Mach OOL FIFO % min(Mach,Mach OOL) better than FIFO 100 10 26 29 290 200 11 26 30 272 500 12 29 30 250 1024 11 34 30 272 2048 15 36 31 206 3072 16 39 32 200 4096 14 29 36 257 5120 19 25 37 194 6144 66 27 34 125 7168 53 26 38 146 8192 70 26 59 226 9216 81 25 66 264 1048576 1822 33 2623 7948 5242880 11536 37 13125 35472 7340032 15693 41 17960 43804
```

---

### Named IPC on OS X
**URL:** https://chromium-dev.chromium.narkive.com/p2wT1ftr/named-ipc-on-os-x

```text
Hey folks...We think we need something equivalent to named pipes on Linux andMacOS to support cloud print and remoting. Basically these servicesare going to be daemons that can outlive the chrome process thatcreated them, and we need future chrome processes to be able to findthem and control them.Currently the IPC implementation on Linux and MacOS is based onsockets (aside from the basic support for fifos that is sort of inthere).On Linux fifos appear to be the correct answer for us (although we aregoing to have to check their performance vs sockets). On the Machowever it would appear that Mach IPC is probably the better choice.I saw the excellent write up on Mach IPC in Chrome here http://www.chromium.org/developers/design-documents/os-x-interprocess-communicationand checked out the code that was herehttp://code.google.com/p/chromium/issues/detail?id=5308(of course I had started to put together my own implementationbefore I stumbled over these).One of the key reasons that Mach IPC was originally dismissed appearsto be because you couldn't block a kqueue on a Mach port on 10.5,however this appears to have changed in 10.6 (search forEVFILT_MACHPORT here http://developer.apple.com/mac/library/documentation/Darwin/Reference/ManPages/man2/kqueue.2.html).What I would like to suggest is possibly moving over to Mach IPC, andconditionalizing (sp?) it for 10.5 vs 10.6 which would mean taking thesmall speed hit on 10.5, but using the native kqueue support on 10.6.This should give us a net performance win on 10.6 overall, and get usthe named IPC that we need to support cloud print and remoting.Any comments? Suggestions?Cheers,Dave
...
I'm generally supportive of this.Possible disadvantages of moving to Mach IPC:* Speed hit due to needing an extra thread-per-ipc-channel to do the workof EVFILT_MACHPORT on 10.5.* Inability to send FDs over a Mach port (I think our only use of this is tosend shared memory handles between processes, we can probably solve this bymoving our shared memory implementation to be vm_allocate() based andsending shared memory regions between processes using OOL transfer).Advantages of Mach IPC:* Possible speed improvement.* Possible ability to send lighter weight shared memory between processes asdescribed above.Things to consider:* As described in the design doc, you may need some kind of handshake tomake sure only authorized processes can connect back to the mach port.* The data gathering interface used by the task manager (which I think Nicowrote) is Mach-based, might make sense to port this to use the Mach IPCmechanism as well.Best regards,Jeremy
...
Post by Jeremy Moskovich I'm generally supportive of this.* Speed hit due to needing an extra thread-per-ipc-channel to do thework of EVFILT_MACHPORT on 10.5.* Inability to send FDs over a Mach port (I think our only use ofthis is to send shared memory handles between processes, we canprobably solve this by moving our shared memory implementation to bevm_allocate() based and sending shared memory regions betweenprocesses using OOL transfer).* Possible speed improvement.* Possible ability to send lighter weight shared memory betweenprocesses as described above.* As described in the design doc, you may need some kind ofhandshake to make sure only authorized processes can connect back tothe mach port.* The data gathering interface used by the task manager (which Ithink Nico wrote) is Mach-based, might make sense to port this touse the Mach IPC mechanism as well.Best regards,JeremyOn Wed, Aug 25, 2010 at 9:10 AM, Dave MacLachlanHey folks...We think we need something equivalent to named pipes on Linux andMacOS to support cloud print and remoting. Basically these servicesare going to be daemons that can outlive the chrome process thatcreated them, and we need future chrome processes to be able to findthem and control them.Currently the IPC implementation on Linux and MacOS is based onsockets (aside from the basic support for fifos that is sort of inthere).On Linux fifos appear to be the correct answer for us (although weare going to have to check their performance vs sockets). On the Machowever it would appear that Mach IPC is probably the better choice.I saw the excellent write up on Mach IPC in Chrome here http://www.chromium.org/developers/design-documents/os-x-interprocess-communicationand checked out the code that was here http://code.google.com/p/chromium/issues/detail?id=5308(of course I had started to put together my own implementationbefore I stumbled over these).One of the key reasons that Mach IPC was originally dismissedappears to be because you couldn't block a kqueue on a Mach port on10.5, however this appears to have changed in 10.6 (search forEVFILT_MACHPORT here http://developer.apple.com/mac/library/documentation/Darwin/Reference/ManPages/man2/kqueue.2.html).What I would like to suggest is possibly moving over to Mach IPC,and conditionalizing (sp?) it for 10.5 vs 10.6 which would meantaking the small speed hit on 10.5, but using the native kqueuesupport on 10.6. This should give us a net performance win on 10.6overall, and get us the named IPC that we need to support cloudprint and remoting.Any comments? Suggestions?Cheers,Dave
...
Post by Dave MacLachlan Hey folks...We think we need something equivalent to named pipes on Linux and MacOS tosupport cloud print and remoting. Basically these services are going to bedaemons that can outlive the chrome process that created them, and we needfuture chrome processes to be able to find them and control them.Currently the IPC implementation on Linux and MacOS is based on sockets(aside from the basic support for fifos that is sort of in there).On Linux fifos appear to be the correct answer for us (although we aregoing to have to check their performance vs sockets). On the Mac however itwould appear that Mach IPC is probably the better choice.I saw the excellent write up on Mach IPC in Chrome herehttp://www.chromium.org/developers/design-documents/os-x-interprocess-communicationand checked out the code that was herehttp://code.google.com/p/chromium/issues/detail?id=5308 (of course I hadstarted to put together my own implementation before I stumbled over these).One of the key reasons that Mach IPC was originally dismissed appears tobe because you couldn't block a kqueue on a Mach port on 10.5, however thisappears to have changed in 10.6 (search for EVFILT_MACHPORT herehttp://developer.apple.com/mac/library/documentation/Darwin/Reference/ManPages/man2/kqueue.2.html).What I would like to suggest is possibly moving over to Mach IPC, andconditionalizing (sp?) it for 10.5 vs 10.6 which would mean taking the smallspeed hit on 10.5, but using the native kqueue support on 10.6. This shouldgive us a net performance win on 10.6 overall, and get us the named IPC thatwe need to support cloud print and remoting.Any comments? Suggestions?Cheers,Dave
...
it wouldappear that Mach IPC is probably the better choice.I saw the excellent write up on Mach IPC in Chromehere http://www.chromium.org/developers/design-documents/os-x-interprocess-communicationandchecked out the code that washerehttp://code.google.com/p/chromium/issues/detail?id=5308 (ofcourse I hadstarted to put together my own implementation before I stumbledover these).One of the key reasons that Mach IPC was originally dismissedappears to bebecause you couldn't block a kqueue on a Mach port on 10.5, howeverthisappears to have changed in 10.6 (search for EVFILT_MACHPORThere http://developer.apple.com/mac/library/documentation/Darwin/Reference/ManPages/man2/kqueue.2.html).What I would like to suggest is possibly moving over to Mach IPC, andconditionalizing (sp?) it for 10.5 vs 10.6 which would mean takingthe smallspeed hit on 10.5, but using the native kqueue support on 10.6.This shouldgive us a net performance win on 10.6 overall, and get us the namedIPC thatwe need to support cloud print and remoting.Any comments? Suggestions?Cheers,Dave--http://groups.google.com/a/chromium.org/group/chromium-dev
```

---

### async-mach-ports 0.1.0 - Docs.rs
**URL:** https://docs.rs/crate/async-mach-ports/latest/source/src/reactor.rs

```text
Typed async channels between unrelated processes over Mach ports, with a k
...
//! Turning "a Mach port has a message" ... "a waker fires".
//!
//! `EVFILT_MACHPORT` is the only kernel mechanism that lets an executor poll a
//! Mach port. One process-wide kqueue holds every registered port, serviced by
//! a single thread blocked in `kevent`.
//!
//! Registrations are `EV_ONESHOT` and must be re-armed by the next
//! `Poll::Pending`: messages are drained with `mach_msg`, not through
//! `kevent`, so a level-triggered registration would stay ready forever and
//! spin.
//!
//! Every caller must try to receive *before* it waits, and must re-arm before
//! returning `Pending` — a message that arrived before the registration
//! existed produces no event at all, so a wait-first loop would hang on a
//! message already sitting in the queue.
...
/// The process-wide kqueue and the wakers waiting on it.
struct Reactor {
    kqueue: OwnedFd,
    /// One waker per port. A port is only ever awaited by one task, so
    /// replacing an existing entry means the previous future was dropped.
    wakers: Mutex<HashMap<mach_port_t, Waker>>,
}
...
, started on first
...
fn global()
...
first and only a successful ... is ever published.
...
reactor) = REACTOR
...
return Ok( ... );
        }
...
// SAFETY: `kqueue` takes no arguments and returns a descriptor or -1.
        let raw = unsafe { libc::kqueue() };
        if raw < 0 {
            return Err(Error::Io(std::io::Error::last_os_error()));
        }
        // SAFETY: `raw` is a fresh descriptor nothing else owns.
        let kqueue = unsafe { OwnedFd::from_raw_fd(raw) };

        let reactor: &'static Reactor = Box::leak(Box::new(Reactor {
            kqueue,
            wakers: Mutex::new(HashMap::new()),
        }));
...
match REACTOR.set(reactor) {
            Ok(()) => {
                std::thread::Builder::new()
                    .name("mach-ipc-reactor".into())
                    .spawn(|| reactor.run())
                    .map_err(Error::Io)?;
                Ok(reactor)
            }
            // Another thread won the race; the reactor built here is simply
            // leaked (this happens at most once in the process's life).
            Err(_) => Ok(REACTOR.get().expect("the winner published its reactor")),
        }
    }

    /// Blocks in `kevent` forever, waking whoever asked about each port.
    fn run(&self) {
        let mut events: [libc::kevent; EVENT_BATCH] = unsafe { std::mem::zeroed() };
        let capacity = c_int::try_from(events.len()).expect("the batch is small");
        loop {
            // SAFETY: `events` is a valid array of the stated length; a null
            // timeout blocks until something arrives.
            let count = unsafe {
                libc::kevent(
                    self.kqueue.as_raw_fd(),
                    std::ptr::null(),
                    0,
                    events.as_mut_ptr(),
                    capacity,
                    std::ptr::null(),
                )
            };

            if count < 0 {
                let err = std::io::Error::last_os_error();
                if err.kind() == std::io::ErrorKind::Interrupted {
                    continue;
                }
                // The kqueue is unusable. Wake everyone so their `try_recv`
                // reports the real error rather than hanging forever.
                let drained: Vec<Waker> = self
                    .wakers
                    .lock()
                    .unwrap_or_else(std::sync::PoisonError::into_inner)
                    .drain()
                    .map(|(_, waker)| waker)
                    .collect();
                for waker in drained {
                    waker.wake();
                }
                return;
            }

            for event in &events[..usize::try_from(count).expect("count is non-negative")] {
                // `ident` holds the port name this registration was made with,
                // so anything that does not fit was never one of ours.
                let Ok(port) = mach_port_t::try_from(event.ident) else {
                    continue;
                };
                let waker = self
                    .wakers
                    .lock()
                    .unwrap_or_else(std::sync::PoisonError::into_inner)
                    .remove(&port);
                if let Some(waker) = waker {
                    waker.wake();
                }
            }
        }
    }

    /// Arms a one-shot registration for `port` and records `waker`.
    ///
    /// The waker is stored *before* the registration is armed. The reverse
    /// order races: the reactor thread could see the event and look for a waker
    /// that has not been stored yet, and the wakeup would be lost.
    fn arm(&self, port: mach_port_t, waker: &Waker) -> Result<()> {
        self.wakers
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .insert(port, waker.clone());

        let mut change: libc::kevent = unsafe { std::mem::zeroed() };
        change.ident = port as usize;
        change.filter = libc::EVFILT_MACHPORT;
        change.flags = (EventFlags::ADD | EventFlags::ONESHOT).bits();

        // SAFETY: `change` is one initialised kevent and no events are read
        // back, so the output pointer may be null.
        let rc = unsafe {
            libc::kevent(
                self.kqueue.as_raw_fd(),
                &raw const change,
                1,
                std::ptr::null_mut(),
                0,
                std::ptr::null(),
            )
        };

        if rc < 0 {
            self.wakers
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner)
                .remove(&port);
            return Err(Error::Io(std::io::Error::last_os_error()));
        }
        Ok(())
    }

    /// Forgets any pending interest in `port`, so a dropped future leaves
    /// nothing behind that could wake into a freed task.
    fn disarm(&self, port: mach_port_t) {
        self.wakers
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .remove(&port);

        let mut change: libc::kevent = unsafe { std::mem::zeroed() };
        change.ident = port as usize;
        change.filter = libc::EVFILT_MACHPORT;
        change.flags = EventFlags::DELETE.bits();

        // SAFETY: as in `arm`. A failure here means the registration was
        // already consumed or never existed, which is the desired end state
        // anyway, so the result is deliberately ignored.
        unsafe {
            libc::kevent(
                self.kqueue.as_raw_fd(),
                &raw const change,
                1,
                std::ptr::null_mut(),
                0,
                std::ptr::null(),
            );
        }
    }
}
...
/// Asks to be woken when `port` next has a message.
    ///
    /// Call this only after a receive has reported [`Error::WouldBlock`], and
    /// only immediately before returning [`std::task::Poll::Pending`].
    pub(crate) fn arm(&self, waker: &Waker) -> Result<()> {
        Reactor::global()?.arm(self.port, waker)?;
        self.armed.set(true);
        Ok(())
    }
}
```

---

### Mach ports - Darling Docs
**URL:** https://docs.darlinghq.org/internals/macos-specifics/mach-ports.html

```text
Mach ports are the IPC primitives under Mach. They are conceptually similar to Unix pipes, sockets or message queues: using ports, tasks (and the kernel) can send each other messages.
...
- Tasks and the kernel itself can enqueue and dequeue messages to/from a port via a port right to that port. A port right is a handle to a port that allows either sending ( ... queuing) or ... (dequeuing) messages, a lot ... a file descriptor ... the read or the write end of a pipe. There ... port rights:
...
- Port set right, which denotes a port set rather than a single port. Dequeuing a message from a port set dequeues a message from one of the ports it contains. Port sets can be used to listen on several ports simultaneously, a lot like `select`/`poll`/`epoll`/`kqueue` in Unix.
...
things, that ... not to explicitly check ... For example, you can manipulate any task (with calls like `vm_write()` and `thread_create()`) ... long as you can ... matter if you ... t exist on
...
the kernel. This port allows ... to, including ... virtual memory, ... and otherwise manipulating its threads, and terminating (killing) the task ( ... task.defs, mach_vm.defs and vm_map.defs). Call `mach_task_ ... ()` to get ... for this port ... the caller task. This port is only ... ()`; a new task ... a new task ... (as a special case ... ). The Mach `task_create()` ... that allows creating ... but it's unavailable ... only way to
...
There also exists `task_set_special_port()` (and the wrapper macros) that allows you to change the special ports for a given task to any send right you provide. `mach_task_self()` and all the other APIs discussed above will, in fact, return these replaced ports rather than the real ports for the task, host and so on. This is a powerful mechanism that can be used, for example, to disallow task to manipulate itself, log and forward any messages it sends and receives (Hurd's `rpctrace`), or make it believe it's running on a different version of the kernel or on another host. This is also how tasks get the bootstrap port: the first task (launchd) starts with a null bootstrap port, allocates a port and sets it as the bootstrap port for the tasks it spawns.
...
As a Darwin extension, there are `pid_for_task()`, `task_for_pid()`, and `task_name_for_pid()` syscalls that allow converting between Mach task ports and Unix PIDs. Since they essentially circumvent the capability model (PIDs are just integers in the global namespace), they are crippled on iOS/macOS with UID checks, entitlements, SIP, etc. limiting their use. On Darling, they are unrestricted.
...
To get the reply from the server, MIG includes a port right (called the reply port) in the message, and then performs a send on the server port and a receive on the reply port with a single `mach_msg()` call. The client keeps the receive right for the reply port, while the server gets sent a send-once right. This way, event though MIG reuses a single (per-thread) reply port for all the servers it talks to, servers can't impersonate each other.
...
MIG supports a bunch of useful options and features. It's extensively used in Mach for RPC (remote procedure calls), including for communicating between the kernel and the userspace. Other than a few direct Mach traps such as `msg_send()` itself, Mach kernel API functions (such as the ones for task and port manipulation) are in fact MIG routines.
...
XPC is a newer IPC framework from Apple, tightly integrated with launchd. Its lower-level C API allows processes to exchange plist-like data via Mach messages. Higher-level Objective-C API (`NSXPC*`) exports a proxying interface similar to Distributed Objects. Unlike Distributed Objects, it's asynchronous, doesn't try to hide the possibility of connection errors, and only allows passing whitelisted types (to prevent certain kinds of attacks).
...
Note that Apple's version of Mach as used in XNU/Darwin is subtly different than both OSF Mach and GNU Mach.
```

---


## 3. Memory Management Overhead

### Linux Terminal Memory Usage | Hacker News
**URL:** https://news.ycombinator.com/item?id=48099790

```text
Linux Terminal Memory Usage | Hacker News

Linux Terminal Memory Usage (gilesorr.com)

54 points by speckx 3 months ago | hide | past | favorite | 49 comments

amarshall 3 months ago | next [–]

Probably want `kitty --single-instance` to reduce memory usage when opening multiple.

https://sw.kovidgoyal.net/kitty/invocation/#cmdoption-kitty-...

jstimpfle 3 months ago | prev | next [–]

I've been on xterm since I've started using Linux seriously in 2008. I probably wouldnt have tested it because was probably a bit obscure then like it is now. It's not perfect, it's baroque, has terrible configurability, no tabs and an ugly context menu. But it's honestly the only usable terminal, none other has stuck with me. Most are far too sluggish to even start up. Then there is key input latency. Then some of the newer ones are only usable with good gpu support, but not from a VM like Virtualbox or maybe VMware where graphics isnt working great.

Another thing for a very long time has been that most other terminals don't support bitmap fonts. This was/is critical for lower DPI monitors. Today I've mostly made the switch to TTF fonts.

lelanthran 3 months ago | parent | next [–]

Thank God for this comment, for a minute I thought I was the only one!

I've been using plain xterm/uxterm with black on white since 2000 at least.

With Vim gaining :terminal support, I need nothing else - I have tabs, splits, proper scrollback buffer navigation because the scroll buffer is a vim buffer...

Honestly, only emacs is a better terminal.

jstimpfle 3 months ago | parent | prev | next [–]

> I probably wouldnt have tested it

(if not for a nerdy sysadmin/hacker person that introduced me to all of that at the time). Was typing on smartphone half-asleep...

AdieuToLogic 3 months ago | parent | prev | next [–]

I used to like rxvt (or its clone rxvt-unicode) when using X-Windows. What are your thoughts about it compared to xterm?

burner420042 3 months ago | root | parent | next [–]

I generally use alacritty but used rxvt back when. That's a name I've not heard in awhile!

I tried `cat /dev/random` in alacritty, rxvt, and xterm to compare output speed. rxvt and xterm both start 'instantly' on my laptop. With alacritty it's slower. Scroll speed of both rxvt and xterm are very similar though xterm seems to win by a little. Both blow the doors off alacritty though.

I'm not sure if this is a fair test, and hence why I posted, but if it is this is a very easy way to get a feel for the difference.

jstimpfle 3 months ago | root | parent | prev | next [–]

It would probably have been the best alternative. I remember it felt similar to xterm, wasn't bloated as many others in the way I described. I don't remember why exactly it didn't stick for me, also don't remember any things it did better. One reason might have been compatibility -- out of the box, most programs work quite well with xterm.

gryffyn 3 months ago | prev | next [–]

I've tried kitty, alacritty, ghostty, wezterm, and konsole (all on X11), but I keep coming back to xfce4-terminal because it opens near instantly and has the least input latency of any of the other terminal emulators I've tried. It also uses very little memory in comparison (with 6 windows open and a fair bit in each scrollback buffer):

```
  Private  +   Shared  =  RAM used Program
  31.2 MiB +  10.7 MiB =  42.0 MiB xfce4-terminal
```

gryffyn 3 months ago | parent | next [–]

I was curious to see what the actual latency was, so I used Pavel Fatin's https://pavelfatin.com/typometer/.

Notes: This system is running Arch, with kernel 7.0.3, scx_bpfland, and i3 on X11. Primary GPU is an integrated Intel GPU.

Using picom:

```
  Terminal                     Min    Max    Avg    SD
  alacritty                    20.1   111.4  43.8   18.0
  xfce4-terminal               19.1   112.5  49.1   17.9
  xterm                        12.3   152.6  53.1   26.4
  wezterm                      28.3   106.0  56.2   15.4
  kitty                        25.3   115.9  57.2   18.5
  ghostty                      19.2   611.8  63.4   45.5
  konsole                      37.9   138.6  68.8   18.5

```

 Using picom --realtime:

```
  Terminal                     Min    Max    Avg    SD
  xterm                        5.7    63.6   15.2   8.8
  alacritty                    7.4    48.8   20.2   9.7
  xfce4-terminal               8.7    65.3   28.3   12.5
  kitty                        13.2   64.8   30.8   10.3
  konsole                      17.3   71.2   31.1   9.5
  ghostty                      12.9   63.7   33.2   11.6
  wezterm                      18.0   58.6   33.6   11.1

```

 No picom:

```
  Terminal                     Min    Max    Avg    SD
  xterm                        4.5    20.4   8.6    1.0
  alacritty                    9.2    13.3   11.1   0.7
  xfce4-terminal               7.4    17.5   11.3   0.9
  ghostty                      11.2   35.3   18.8   3.8
  wezterm                      14.1   34.2   22.7   3.7
  kitty                        12.2   44.3   24.4   5.8
  konsole                      17.2   30.7   25.0   3.6

```

 Running on the NVIDIA GPU just for fun:

```
  wezterm (no picom, NVIDIA)   21.7   51.2   34.8   8.1
  wezterm (picom rt, NVIDIA)   22.0   70.9   41.4   11.2
  wezterm (NVIDIA)             34.4   146.7  69.0   17.8

```

 Slightly surprised that xterm doesn't top the chart on the picom category.

sebtron 3 months ago | prev | next [–]

> I expected gnome-terminal's memory usage to be in line with konsole (KDE's default terminal), but gnome-terminal shows remarkably well in this test

In tipical GNOME fashion, they have decided to replace this largely working piece of software with on with one that places solidly at the bottom of the article's list (ptyxis).

Almost all of that is Mesa shaders and GTK's CPU side font-cache for GL/Vulkan, compiled CSS state, FWIW.

If you run:

GSK_RENDERER=cairo ptyxis -s

You can verify that with 69,985 here RES and 52,428 of that SHR. With 5 tabs open it jumped to 71,208 here. Presumably for the encrypted scrollback pre-allocations.

You still may not choose to use it, but it should stay relatively similar the more tabs you open.

Also, it's not a core GNOME app. It's just an app I wrote for me that the distros seem to have liked for its design/platform integration.

freedomben 3 months ago | root | parent | next [–]

Thanks for writing it! I was very skeptical initially, but after using it I'm a fan. I also appreciate that I can script settings using gsettings, so I can configure it easily on new systems without having to touch the GUI (though the GUI settings are well thought out and nice to use when you don't know what you need yet).

scheme271 3 months ago | parent | prev | next [–]

ptyxis has a few features that gnome-terminal doesn't and which are really handy. Namely, being able to list containers running on the system and then being able to select one to get a terminal running inside the container. Not sure that warrants replacing gnome-terminal but it is really handy if you use containers a lot.

audidude 3 months ago | root | parent | next [–]

The good news is that before writing Ptyxis, I also ported GNOME Terminal to GTK 4 and doubled the performance of VTE. So you know, use whatever you like.

simonask 3 months ago | root | parent | next [–]

Hey thanks for your work, I’m really enjoying Ptyxis on Arch.

willis936 3 months ago | root | parent | prev | next [–]

Cool, but can you set the colors?

kokada 3 months ago | parent | prev | next [–]

Wait, what? ptyxis is not the default GNOME termjnal. It is the terminal of choice for both Ubuntu and Fedora, but the default terminal in GNOME is Console, internally known as kgx: https://en.wikipedia.org/wiki/GNOME_Terminal.

dwheeler 3 months ago | root | parent | next [–]

Gnome Console seems to be intended for people who don't use terminals. I quickly install GNOME terminal for real use.

kokada 3 months ago | root | parent | next [–]

I was using GNOME Console in a postmarketOS install in my Chromebook. The fact that it is lightweight compared to say Ghostty (my main terminal everywhere else) made a difference in performance for such a constraint device.

And I didn't really miss any features to be honest, it has the basic that you expect (things like tabs). It is less customizable than other options, but the defaults were good enough for me.

sebtron 3 months ago | root | parent | prev | next [–]

I did not know about this. I used it on Fedora, and I thought Fedora was as close to "default GNOME" as possible.

Today I learned (thanks to this article) that I can use timg to display images right in my standard macOS terminal, even without switching to kitty or any other fancy thing. Not pixel perfect of course, but still, much faster to go through icons or other pictures than opening in a separate Preview window. A simple "brew install timg" worked for me. Will surely save me some clicks!

menno-sh 3 months ago | parent | next [–]

For that specific use case you could also try `yazi`[0], which is a TUI file browser that has image (and other filetypes) preview built in.

[0] https://github.com/sxyazi/yazi

magios 3 months ago | prev | next [–]

i've been using xst https://github.com/gnotclub/xst, a fork of suckless st https://st.suckless.org/ for a long period, but there's also st-flexipatch https://github.com/bakkeby/st-flexipatch available which now includes sixel support

edit: the article did mention st but claimed it had no scrollback, that's what the patches are for. st-flexipatch makes it easy to enable or disable the patches via c preprocessor defines.

archargelod 3 months ago | prev | next [–]

I've been using st-terminal[1] for 5-6 years at this point. It starts instantly, uses ~10mb of Ram and has almost zero latency. It's especially apparent on X11 without compositing enabled.

I tried ghostty the last year and I was instantly turned off by how much ram it hogs, but even more horrible was that it was using close to 10% cpu just sitting idly, doing absolutely nothing. It also felt at least twice as slow.

I need my terminal to display text, do scrollback and nothing else. I don't need gpu rendering, I don't need any fancy features, just be respectful to my system resources. Is it too much to ask?

[1] https://st.suckless.org/

celrod 3 months ago | prev | next [–]

foot also offers a client/server architecture. If you start a foot server (e.g. with a systemd service), you can use `footclient -N`. This may reduce the memory pressure of running many terminals.

This is similar to the `kitty --singleinstance` mentioned in another comment by amarshall.

jiqiren 3 months ago | prev | next [–]

Why not try Ghostty? https://ghostty.org

skeledrew 3 months ago | parent | next [–]

He said it: because it isn't in Debian repos.

esseph 3 months ago | root | parent | next [–]

One of many reasons I left Debian behind for desktop things over a decade ago. I love the project and appreciate the history, but things can get pretty long in the tooth after awhile. Flatpaks help.

giancarlostoro 3 months ago | root | parent | next [–]

I wish Debian had an Arch style bleeding edge fork. Till then I've been happy using Arch, I had my last straw when a program needed a more up to date GLIBC on Debian. That's such a can of worms to resolve, I just went ahead and gave Endeavour (Arch based) a try and havent gone back or changed distros ever since.

If someone ever makes a Debian distro that is bleeding edge and supports Nvidia drivers (basically a more bleeding edge Ubuntu) I'd be all ears.

Wowfunhappy 3 months ago | root | parent | next [–]

Aren't you describing either Debian Testing or Debian Unstable? (Depending on just how bleeding edge you want.)

giancarlostoro 3 months ago | root | parent | next [–]

You cannot find nvidia drivers on there. The philosophy of Debian forbids it.

kevin_thibedeau 3 months ago | root | parent | prev | next [–]

Just download the source and build the binaries you need. I use GNU stow as a parallel package manager within /usr/local that plays nice with the rest of the OS. It isn't hard for most sane programs with proper build scripting.

esseph 3 months ago | root | parent | next [–]

Went to an atomic distro + flatpak.

d3Xt3r 3 months ago | root | parent | prev | next [–]

That's an odd reason. There's many ways to get packages these days without being dependent on your distro's repos (like using brew or Nix, or just grabbing the binaries directly). Ghostty is a very popular terminal right now, so it's a shame that the author left it out of the comparison.

jbverschoor 3 months ago | root | parent | next [–]

the (walled) garden is a very good place to be

ac29 3 months ago | parent | prev | next [–]

Its horrible with memory, launching a single empty terminal uses 307MiB on my Linux system

pdpi 3 months ago | root | parent | next [–]

My current Ghostty session on macOS is holding on to 127.8 MiB of real memory, and only 37.5 MiB of private memory. What's the Linux build up to that makes up for that difference?

Piraty 3 months ago | prev | next [–]

there is more to your choice of terminal emulators than pure memory usage.

https://lwn.net/Articles/749992/

https://lwn.net/Articles/751763/

Bender 3 months ago | prev | next [–]

I've honestly never given terminal memory usage a second thought. Here is the memory usage of konsole version 26.04.1 on CachyOS.

```
     Private  +   Shared  =  RAM used       Program
     53.3 MiB +  25.1 MiB =  78.5 MiB       konsole

```

 Above is with two tabs open. Below is 18 tabs open. In the settings the memory limit is set to 192 MB (Default)

```
     Private  +   Shared  =  RAM used       Program
     61.9 MiB +  33.1 MiB =  95.0 MiB       konsole

```

 Using ps_mem.py [1] - I suggest using this instead of ps to avoid confusion around shared memory.

[1] - https://github.com/pixelb/ps_mem

Jotalea 3 months ago | prev | next [–]

as a Hyprland user, i think the eye candy in kitty is worth the extra memory usage. at least for me, it makes the experience much smoother.

currently considering trying out ratty, a terminal emulator with 3D graphics rendering capabilities.

eahm 3 months ago | prev | next [–]

Why is xfce4-terminal missing?

minus7 3 months ago | parent | next [–]

It's just using libvte like gnome-terminal and lxterminal, so I doubt it's much different from them.

eahm 3 months ago | root | parent | next [–]

Oh I see, about Terminator?

beej71 3 months ago | parent | prev | next [–]

/usr/bin/xfce4-terminal 64176

I like xfce4-terminal as a compromise. Good bang for the memory buck.

jmclnx 3 months ago | prev | next [–]

I use to have a few terms active in the very early days of Linux. When I heard about screen/tmux now I just have 1 term open and multiple tmux sessions.

I think if you can get use to tmux/screen you may like that better :)

somat 3 months ago | parent | next [–]

I find A good window manager to be nicer for a bunch of terminals than tmux, where tmux really shines is when you want a bunch of terminals on a remote system.

skeledrew 3 months ago | parent | prev | next [–]

I've faced the many terminal tabs issue. In a way tmux actually makes it worse as I'm used to the running app being in the title, and tmux obscures that (now there's just "client"). But also better as I found a great session restore plugin; always drove me a bit crazy when something happened that either killed the terminal app or triggered a full restart, and my tabs were lost.

kevin_thibedeau 3 months ago | root | parent | next [–]

```
  set -g automatic-rename on
  set -g automatic-rename-format '#{pane_current_command}'
```

dxxvi 3 months ago | prev [–]

I'm using wezterm in KDE Plamas in Wayland.
```

---


## 4. Shell Engine & Initialization Optimization (fish/zsh)

### Conda init slows shell startup immensely | Hacker News
**URL:** https://news.ycombinator.com/item?id=42562112

```text
Conda init slows shell startup immensely | Hacker News

Conda init slows shell startup immensely | Hacker News||[![](y18.svg)](https://news.ycombinator.com)|**[Hacker News](news)**[new](newest) | [past](front) | [comments](newcomments) | [ask](ask) | [show](show) | [jobs](jobs) | [submit](submit)|[login](login?goto=item?id=42562112)|
|
||[
](vote?id=42562112&how=up&goto=item?id=42562112)|[Conda init slows shell startup immensely](https://github.com/conda/conda/issues/11648) ([github.com/conda](from?site=github.com/conda))|
||4 points by [behnamoh](user?id=behnamoh)[on Dec 31, 2024](item?id=42562112) | [hide](hide?id=42562112&goto=item?id=42562112) | [past]() | [favorite](fave?id=42562112&auth=adb8341ddb7fdeb9d9014fe65195a78c50b5937d)|
||
|
|
![](s.gif)||
[Consider applying for YC's Summer 2026 batch! Applications are open till May 4](https://www.ycombinator.com/apply/)
[Guidelines](newsguidelines.html) | [FAQ](newsfaq.html) | [Lists](lists) | [API](https://github.com/HackerNews/API) | [Security](security.html) | [Legal](https://www.ycombinator.com/legal/) | [Apply to YC](https://www.ycombinator.com/apply/) | [Contact](mailto:hn@ycombinator.com)
Search: |
```

---

### Why does zsh start so slowly?
**URL:** https://news.ycombinator.com/item?id=33580350

```text
Why does zsh start so slowly? | Hacker News

Why does zsh start so slowly? (pickard.cc)

149 points by todsacerdoti on Nov 13, 2022 | hide | past | favorite | 74 comments

rphln on Nov 13, 2022 | next [–]

I recently had the same problem with Conda's and Pandoc's initializations in Bash.

At first I did the same as the author and just dumped the output from `pandoc --bash-completion` et al. into a file, but then I'd have to deal with cache invalidation on every machine that I use. Doing it manually isn't that bad, but remembering to update the file in a bunch of machines is a bit too much ugly for me.

After a surprisingly short Google session, I ended up settling with lazy initialization [1]. Unlike the post I found, I did it all manually, though. Now I just have this tucked at the end of my `.bashrc`:

```
    function conda {
        unset -f conda

        # shellcheck disable=SC1090
        source <(conda shell.bash hook)
        conda "${@}"
    }

    function _pandoc {
        unset -f _pandoc

        # shellcheck disable=SC1090
        source <(pandoc --bash-completion)
        _pandoc "${@}"
    }

    complete -F _pandoc pandoc

```

 [1]: https://dev.to/zanehannanau/bash-lazy-completion-evaluation-...

paulirish on Nov 13, 2022 | parent | next [–]

I've also spent time profiling shell startup and found conda's init wasn't fast. (And that's consistent in fish shell, tol) Your found solution is elegant; I'll adopt it. nvm and rvm both have initializations have a decent perf hit, too.

dcminter on Nov 13, 2022 | prev | next [–]

Not really related, but this reminds me of an issue I once saw where starting vi on one of our servers took something over a minute. Everywhere else it was imperceptibly fast. It eventually turned out that in the distant past someone had accidentally piped a large file into vi, and so every time it started up it was loading up a command history that included this stupidly big file to absolutely no purpose, annoying everyone but not quite enough that anyone else had tracked down the cause.

mort96 on Nov 13, 2022 | parent | next [–]

Interesting, that'd surely become an issue over time with normal usage as well if it never deletes old entries?

dcminter on Nov 13, 2022 | root | parent | next [–]

Seems the default limit is 20 commands - perhaps someone had overridden it to be much higher. It was about a decade ago though so I may be misremembering something about the issue.

decasia on Nov 13, 2022 | prev | next [–]

Bonus points if zsh measured startup time by default and issued periodic warnings about slow startup dependencies. I wouldn't mind seeing the occasional message to STDERR telling me that `kubectl xyz` is actually adding 250ms to shell startup.

KerrAvon on Nov 13, 2022 | parent | next [–]

This sounds like a great thing to put in the zsh issue tracker.

ngshiheng on Nov 13, 2022 | prev | next [–]

Interesting. In my case, according to `zprof`, 80% of my startup time came from nvm_auto from nvm (node version manager)

it_citizen on Nov 13, 2022 | parent | next [–]

```
  # This lazy loads nvm
  nvm() {
    unset -f nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use # This loads nvm
    nvm $@
  }

```

 Now, nvm only loads when it is explicitly called instead of loading in every shell. In my case, it made a very visible speed difference.

eyelidlessness on Nov 13, 2022 | parent | prev | next [–]

Yeah, nvm is notoriously slow. Volta[1] is much faster.

1: https://volta.sh/

chrisweekly on Nov 13, 2022 | parent | prev | next [–]

I switched from nvm to fnm for this (and other) reasons a couple years ago. Huge improvement on all fronts.

mananaysiempre on Nov 13, 2022 | prev | next [–]

Answer: Because it is sourcing the output of `kubectl completion zsh`, which takes 130ms to execute. (The article says something about zsh “caching” a static sourced file; does it actually do something like that? It still has to run the shell code, right?)

Question: How the hell do you take 130ms to print out the commands to set up shell completion? Is there something meaningful happening in that time, or is this simply the cost for the kernel to load a 43 MB do-everything kubectl binary? (43 MB is a lot, admittedly, but 130ms when most of that code stays untouched still sounds high to me.)

oefrha on Nov 13, 2022 | parent | next [–]

> The article says something about zsh “caching” a static sourced file; does it actually do something like that? It still has to run the shell code, right?

No it does not, the article is wrong or phrased incorrectly.

Zsh completion functions, when properly configured, are autoloaded. The function is only read from disk when called. Say with _kubectl, if you do it correctly with a static _kubectl instead of following the stupid advice of `source <(kubectl completion zsh)`, on shell startup your _kubectl should be uninitialized:

```
  $ which _kubectl
  _kubectl () {
   # undefined
   builtin autoload -XUz
  }

```

 After you actually try to complete kubectl once, run that again and this time you can see the actual function body.

```
  $ which _kubectl
  _kubectl () {
   local shellCompDirectiveError=1
   # ...
  }

```

 That function is read from disk on use, not cached.

What zsh does cache, with compinit[1], is association of commands with completion functions. compinit reads the #compdef line of functions on $fpath (e.g. `#compdef _kubectl kubectl`), and generates a ~/.zcompdump (or some other path, mine is ~/.local/share/zsh/compdump for instance), which is basically a list of command and completion function pairs, plus a huge autoload invocation registering all the completion functions. This way zsh knows which function to load when a command needs completion.

[1] https://zsh.sourceforge.io/Doc/Release/Completion-System.htm...

vbezhenar on Nov 13, 2022 | parent | prev | next [–]

Kernel does not load 43 MB. It maps file to memory and then executes it from start address. During execution, kernel paging mechanism reads parts of the file into memory as CPU touches it. So ideally this print algorithm should take few kilobytes of those 43 MB and 2-3 pages loaded from the disk. With SSD it should be significantly faster than 130 ms.

What exactly happens with kubectl is hard to answer and need someone to profile it if that's true. May be it checks for updates or something like that.

PetitSasquatch on Nov 13, 2022 | parent | prev | next [–]

I have experienced even longer with npm / Node.js autocompletion.

The whole experience caused me to try different shells, I ended up on ksh for simplicity and comparative leanness, works well for my needs.

ilyt on Nov 13, 2022 | root | parent | next [–]

But zsh is not slow, bloat you add to it is...

PetitSasquatch on Nov 13, 2022 | root | parent | next [–]

I agree. I never found zsh inherently slow, but the reason I initially used it was to play with all the additional 'bloat' its ecosystem offered, so to speak.

It was that experience which led me to look try other shells, in the end I found ksh's simpler feature set and manpage more to my liking.

marcthe12 on Nov 13, 2022 | root | parent | prev | next [–]

Which ksh flavour? Also any good tutorial?

ratsmack on Nov 13, 2022 | root | parent | next [–]

I have used the original ksh[1] for years, because it seem to have more features for complex shell scripts. It also supports real numbers for people that need math functions other than integer.

[1] https://en.wikipedia.org/wiki/KornShell

PetitSasquatch on Nov 13, 2022 | root | parent | prev | next [–]

The ksh that ships with OpenBSD, it's available under Linux as loksh. I've never needed a tutorial as such, because found its man page to be well written and comprehensive. However, I can recommend the old book The Unix Programming Environment by Kernighan and Pike, it also is well written and helped me quite a bit. Just understanding one smaller tool (ksh) better has helped me do more with it and use fewer addons extensions, which personally make me happy; works for me.

jrockway on Nov 13, 2022 | parent | prev | next [–]

It seems odd to run kubectl every time you open the shell. I just save the output and source it in every shell. On my machine it's 40ms to create a shell and eval the output of "kubectl completion bash". It's <10ms to "source ~/.dotfiles/compleation/kubectl".

oweiler on Nov 13, 2022 | parent | prev | next [–]

Probably much, much faster to move the command output to a separate file and sourcing that (which requires no subshell, process substitution etc.).

Myrmornis on Nov 13, 2022 | root | parent | next [–]

Btw, that's precisely the conclusion of the article.

wodenokoto on Nov 13, 2022 | prev | next [–]

Are these autocompletions dynamic? Wouldn’t it make more sense for k8 (and others) to ship a “burned in” completion file and ask users to source that?

nickjj on Nov 13, 2022 | prev | next [–]

Should this include when loading autocompletions in the title?

zsh loads in 105ms for me on a 7 year old workstation but I don't have that source command for Kubernetes' autocompletion in my zshrc. I'm only loading a few plugins such as fast-syntax-highlighting and zsh-autosuggestions. It doesn't load slower than bash in a way that I can perceive.

Nice tip on using the profiler but how do you read the profile output compared to `time zsh -i -c exit`? The blog post you linked mentions running `time zsh -i -c exit` to get the true time which is where I saw the 105ms but none of the columns in the zsh profile table add up to 105ms. If the table reports in milliseconds, the summary table up top adds up to about 41ms for the first time column.

hrbf on Nov 13, 2022 | prev | next [–]

The caching vs. update issue could be trivially addressed by running a daily cronjob to update the static completion file.

aftbit on Nov 13, 2022 | prev | next [–]

One tip if you are using zprof: it only reports time spent in function calls, not in commands run at the top level of .zshrc. Last time I profiled, I ended up binary searching by wrapping different parts of my .zshenv and .zshrc in "zinit1" and "zinit2" then tracking which one took longest. My problem turned out to be a buggy alias that was calling "curl" during construction rather than when it was called.

hn92726819 on Nov 13, 2022 | prev | next [–]

Since nobody has mentioned a tip for his cache problem: I would just solve this with cron. Run it daily and just write the file at 5am then forget about it. Could also spawn a subshell at login to generate the file in the background

This article reminds me of my shellrc which used to have a progress bar. I had it print \r{##..}, with increasing number of # after every big source (2-3 second start. Looking back I don't know how I used that daily

mikelward on Nov 13, 2022 | parent | next [–]

They did here: https://news.ycombinator.com/item?id=33582027

hn92726819 on Nov 13, 2022 | root | parent | next [–]

Whoops! I missed this, thanks

vbezhenar on Nov 13, 2022 | prev | next [–]

Can also use zcompile to further improve loading speed (not sure if measureable, but I did it for the sake of it).

cb321 on Nov 13, 2022 | parent | next [–]

It is quite measurable. Some details. At the top of .zshenv

```
    zmodload zsh/datetime
    [[ -v ZSH_TIME_STARTUP ]] && t0=$EPOCHREALTIME

```

 and at the bottom of .zshrc

```
    [[ -v ZSH_TIME_STARTUP ]] && echo $[EPOCHREALTIME-t0]

```

 This is better than alternatives mentioned here which also time .zlogout - i.e. start up & shut down. Now, when I do something like

```
    (repeat 20 ZSH_TIME_STARTUP= zsh -il -c exit)|sort -g|head -n5|mnsd

```

 I get

```
    0.03635 +- 0.00034

```

 Now if I

```
    rm .zcompdump.zwc digraphs.zsh.zwc

```

 and then repeat the "mean,std.dev of best 5 out of 20" above, I get

```
    0.07270 +- 0.00015

```

 So, basically 2x faster start up time by just by doing zcompile on those two files. Also, if I re-run the (repeat..) then I get numbers within +- 2..3 std.devs. So, the numbers and run-to-run consistency all get along fine.

spockz on Nov 13, 2022 | parent | prev | next [–]

How would you use zcompile? The help page reads to me I need to point it at a file. But which one? .zshrc?

cb321 on Nov 13, 2022 | root | parent | next [–]

A good way to isolate which work is causing slowness is the PS4 variable. This is what is printed in "-x" tracing mode. E.g.:

```
    PS4='+$EPOCHREALTIME ' zsh -ilx -c exit 2>/t/zpro

```

 You need to have `zmodload zsh/datetime` loaded early for that to work..E.g. at the very top of your .zshenv.

It's not hard to do a little post-processing script to have awk do entry-to-entry deltas on that /t/zpro file and then sort those to get a "seconds cmd" kind of report. Personally, I have found this more effective at identifying hotspots than the zprof mentioned in the article.

EDIT: Caveat - There can be a bit of a Heisenberg style disturb what you are measuring effect from trace overheads. For example, the `_comps = (32 kiB report)` always shows up as the most expensive thing for me, but I think that 3.3ms comes mostly from the `-x` just printing the thing out after the timestamp or maybe formatting it for print. If I just do a t0=$EPOCHREALTIME before and echo $[EPOCHREALTIME-t0] after it takes only 1.0 ms in non-traced mode. So, 2.3/3.3 = 70% of the time is just the formatting/printing/-x work.

johnnypangs on Nov 13, 2022 | prev | next [–]

I really enjoy zr(at). I don’t think it will help with specific completions that are slow to load though, but it’s simple, easy to use and can be pretty bare bones.

https://github.com/jedahan/zr

voidz on Nov 13, 2022 | parent | next [–]

Great tip! zr seems very useful.

theptip on Nov 13, 2022 | prev | next [–]

I suppose this is something that Nix would excel at; just inspect the hash of kubectl (or whatever you are running completions for), and reinstall a downstream derivation that caches the completions of it changes.

doublepg23 on Nov 13, 2022 | prev | next [–]

Anyone know the best way to clean up your shell init scripts? Maybe rephrased a better way - what are all files my shell sources on startup? (fish in this case.)

jmclnx on Nov 13, 2022 | prev | next [–]

There you go, large init files = slower loads :)

I setup zsh to work like my tcsh setup to give it a try and used it for a while. Yes the init files in zsh are a bit larger, but I noticed no speed difference at all. In the article it seems they are loading all kinds of things. So I would expect zsh would be slower.

BTW, I am still on tcsh only due to my "muscle memory" and on history the cursor positions at the end of the line instead of the beginning.

cb321 on Nov 13, 2022 | parent | next [–]

Besides large init files, another way to get slow start ups is large history files. I used to set mine to hundreds of thousands of entries until I realized this was slowing down start up time by a factor of several. :-)

iudqnolq on Nov 13, 2022 | root | parent | next [–]

There's always the variety of sqlite history extensions

jck on Nov 13, 2022 | prev | next [–]

You can use a plugin manager like https://github.com/marlonrichert/zsh-snap to cache the output of these commands. Using something like the packages version number as the cache key will ensure that it gets regenerated only once per package update as opposed to every shell launch.

dezzadk on Nov 13, 2022 | prev | next [–]

This tip beats all tips https://asciinema.org/a/274255

You can move the line below your bindkey defs so you still have keys.

vbezhenar on Nov 13, 2022 | parent | next [–]

Excerpt from script comments:

This doesn't actually make your zsh start instantly, hence the reference to the "one weird trick" advertisement. It does, however, make it feel like zsh is loading faster. Or, put it another way, your original zsh wasn't so slow to load, but you thought it was slow. Now you see that it was pretty fast all along.

Here's how it work. To make your zsh "start instantly" all you need to do is print your prompt immediately when zsh starts, before doing anything else. At the top of ~/.zshrc is a good place for this. If your prompt takes a long time to initialize, print something that looks close enough. Then, while the rest of ~/.zshrc is evaluated and precmd hooks are run, all keyboard input simply gets buffered. Once initialization is complete, clear the screen and allow the real prompt be printed where the "loading" prompt was before. With the real prompt in place, all buffered keyboard input is processed by zle.

It's a bit gimmicky but it does reduce the perceived ZSH startup latency by a lot. To make it more interesting, add `sleep 1` at the bottom of zsh and try opening a new tab in your terminal. It's still instant!

dezzadk on Nov 13, 2022 | root | parent | next [–]

True, however at some point you have plugins that take near 1s to load like syntax highlighting and its just not possible to reduce that to 100ms

ilyt on Nov 13, 2022 | root | parent | prev | next [–]

I just start typing command before prompt shows...

hk1337 on Nov 13, 2022 | prev | next [–]

Using zsh now but I had a similar issue with bash-it and it turns out the culprit was that I was running brew —prefix multiple times to get the home brew path instead of using an environment variable.

hfjcic7 on Nov 13, 2022 | prev | next [–]

It doesn't. You've loaded it up with omz.

ibejoeb on Nov 13, 2022 | prev | next [–]

I also had a problem with startup time using zsh. Then I switched to fish. Now I really have a problem...

1letterunixname on Nov 14, 2022 | prev | next [–]

I use powerlevel 10k which does asynchronous startup. It has a cache script that runs early.

bArray on Nov 13, 2022 | prev | next [–]

I think zsh and others (bash, ash, etc) are a problem for many reasons:

1. Poor start-up time. It's not so much a problem if you are opening a terminal, but if you're running shell scripts in a large loop, they could soon become a significant factor of your run time.

2. Too much RAM. I'm looking at my server and bash is taking 2-3MB per script. When you're running a 10's or maybe 100's of little scripts this really adds up.

3. The syntax is wrong. For example in bash, there are more ways to write a loop that I can to mention. Often I find myself wondering if I need no brackets, [], [[]], (), (()) - it really shouldn't be this hard or varied.

4. Proper types. Sometimes you simply don't know if what you have can be parsed as an array or not, or whether you have a string representation of a number.

I haven't yet thought of a better way though. For example, it does a few things right:

1. Piping is really powerful. Where possible I use '|' as it's usually the simplest to understand, when you have multiple arrows < > with numbers on the end it can take a moment to figure out what gets passed where.

2. 'Forking' is super simple. Just throwing an '&' at the end means the command no longer blocks, super cool. I think I would like to see some form of "join" and I know this is possible, but it would be cool if there was a super simple syntax for this too.

Maybe:

```
    pid=$(some command &) # & would return a PID number
    # some time later
    join $pid # How would you know if the PID wasn't re-used?

```

 3. No compilation is great for writing scripts and maintaining portability.

4. The completion saves loads of time. Being able to type 'ls' and tab a few times is great for finding where something is or an option for a command. In the same strength, the history accessible with arrow keys is also really cool.

One thing that could save some time during startup is to have a spare shell already spun up and waiting to be allocated. This would cause some issues with sourcing, but it could be possible to check the timestamps on the sourced files and see whether they require another source just before handing the process over. It's a little hacky though and a better solution would still be to address the performance issues directly.

SAI_Peregrinus on Nov 13, 2022 | parent | next [–]

> 3. The syntax is wrong. For example in bash, there are more ways to write a loop that I can to mention. Often I find myself wondering if I need no brackets, [], [[]], (), (()) - it really shouldn't be this hard or varied.

If you want even weirder syntax, just never use square brackets. Write out `test` commands manually. E.g. instead of `if [ ${string1} = ${string2} ]; then` write `if test ${string1} = ${string2}; then`. `[` is just an alias for `test`. Combining comparisons can get a bit harder to keep track of though, since there's no `]` and `test` allows logical operations with `-a` and similar. Better to call `test` multiple times and use the shell-native `&&` and similar IMO.

hyperhopper on Nov 13, 2022 | parent | prev | next [–]

If you're worrying about loop syntax and types in your Shrek script, you probably should be using a real programming language language instead

bArray on Nov 14, 2022 | root | parent | next [–]

I don't think a clean script is much to ask for. Sometimes a programming language is not particularly appropriate. There's some middle ground where it's complex, but re-writing it in a programming language is a super pain.

ykonstant on Nov 13, 2022 | root | parent | prev | next [–]

Somebody once told me the buffer's overflowing

loops ain't the sharpest tool in the shell.

pedro84 on Nov 13, 2022 | parent | prev | next [–]

RE: #2, would "wait $(jobs -rp)" work for you?

bArray on Nov 14, 2022 | root | parent | next [–]

You learn something new every day. I had a quick look [1], seems quite usable!

[1] https://www.linuxjournal.com/content/job-control-bash-featur...

FBISurveillance on Nov 13, 2022 | prev | next [–]

Pro tip: add `zmodload zsh/zprof` at the beginning of your zshrc and `zprof` at the end, open a new shell to see those pesky long-loading sources as a nicely formatted trace with timings.

greymalik on Nov 13, 2022 | parent | next [–]

That’s covered in TFA.

csdvrx on Nov 13, 2022 | root | parent | next [–]

The core problem is using too many modules, and frameworks like oh-my-zsh look good, but don't give you much visibility on the internals.

When I was using MSYS2 (cygwin based, so with a slow fork) I ended up writing my own solution for a cute prompt and history logging to sqlite with a fzy frontend because the existing solutions were all made for Linux and assumed among other things fast forks.

suprfnk on Nov 13, 2022 | parent | prev | next [–]

This is in the article:

> the tl;dr is to add zmodload zsh/zprof add the very top of your ~/. zshrc and zprof to the very bottom, then restart the shell. On startup, you will see a table with everything impacting your shell startup time.

FBISurveillance on Nov 13, 2022 | root | parent | next [–]

Ah yes, I wanted to play GPT-3 and posted what I think the summary is here as a comment.

jokethrowaway on Nov 13, 2022 | prev | next [–]

Moved to fish because of this but I'm annoyed at all the incompatibilities

1letterunixname on Nov 14, 2022 | parent | next [–]

Which "incompatibilities"?

raydiatian on Nov 13, 2022 | prev | next [–]

Glad I’m not the only one that finds Zsh slow to start

mikelward on Nov 13, 2022 | parent | next [–]

Zshrc is slow if you put slow things in it.

In the article, the author was running kubectl in their zshrc. kubectl was slow. This doesn't prove zsh is slow.

raydiatian on Nov 13, 2022 | root | parent | next [–]

My wording is pretty clear, that’s no claim to have proof. My working understanding is that .rc files are common for shell init. If it turns out that .rc files slow down any shell du jour significantly, then TIL, I don’t know much about the inner workings of shells and haven’t had a practical reason to learn.

In any case, I’d like to apologize because I clearly offended you somehow, despite being a fellow zsh user and for that I am sorry.

mkonecny on Nov 14, 2022 | root | parent | next [–]

You may as well have said "Im glad im not the only one who noticed Linux/Mac OS is slow" or Intel/AMD is slow or bash/fish/ksh is slow

My working understanding is that a program is common to run on these OS'es/hardware/shells :/

raydiatian on Nov 14, 2022 | root | parent | next [–]

I am glad I’m not the only one who noticed Linux/Mac OS is slow

hn92726819 on Nov 13, 2022 | parent | prev | next [–]

The title is misleading as it has nothing tk do with zsh being slow.

He basically had a sleep statement in his .zshrc and removed it.

raydiatian on Nov 14, 2022 | root | parent | next [–]

Whether or not the title is misleading, my experience is that my zsh loads slowly. You are downvoting me for sharing my genuine real world experience with a program. I’m sorry I hurt your feelings with my real life.

hn92726819 on Nov 21, 2022 | root | parent | next [–]

My feelings? Your comment demonstrated a misunderstanding of the article. Also I don't have enough karma to down vote anyone on hackernews.

If your zsh is slow to start, I suggest commenting your entire zshrc and then binary searching it to see what's slow (uncomment the top half only, then bottom half, then the top half of the slow half).

raverbashing on Nov 13, 2022 | prev [–]

Interesting. I assumed it was because it always pinged GitHub(?) for updates

But yeah, caching static source scripts should help

mattgreenrocks on Nov 13, 2022 | parent [–]

I think that’s oh-my-zsh, not zsh itself.

Stuff like this is why I’m not a big fan of OMZ: it clouds people’s perceptions of what zsh is/isn’t.
```

---

### I followed this advice and my shell went from 1530ms to 35ms startup time. Main ... | Hacker News
**URL:** https://news.ycombinator.com/item?id=39103243

```text
I followed this advice and my shell went from 1530ms to 35ms startup time. Main ... | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

joejag on Jan 23, 2024| parent| context| favorite| on: Oh My Zsh

I followed this advice and my shell went from 1530ms to 35ms startup time.

Main culprits were language switchers (nvm, jabba, pyenv). Which I moved to lazy loading.

If I drop the ohmyzsh plugins startup time is 11ms. But, I want some quality of life.

There's a nice benchmarking command in the article if you want to test yours:

for i in $(seq 1 10); do /usr/bin/time $SHELL -i -c exit; done

wrboyce on Jan 23, 2024 [–]

That benchmark command isn’t great: https://github.com/romkatv/zsh-bench#how-not-to-benchmark

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### Oh My Zsh
**URL:** https://news.ycombinator.com/item?id=39100308

```text
Oh My Zsh | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

| Oh My Zsh(ohmyz.sh) |
| --- |
| 159 points by praash on Jan 23, 2024| hide| past| favorite| 147 comments |

pprotas on Jan 23, 2024| [–]

Do yourself a favor and try to configure your shell without ohmyzsh first. You’d be surprised at how few plugins actually require it, and you save yourself from horrible performance.

d3w4s9 on Jan 23, 2024| | [–]

I do myself a favor by not doing this, install ohmyzsh and start working. Seeing what other people have done with shell, vim and all sorts of things, I know this is a rabbit hole and I could spend endless time on it. That's why I use ohmyzsh, VSCode and other tools and only tweak settings when necessary. And I can be actually productive even when I get a new machine.

Performance? If you are talking about the startup performance, no it doesn't bother me. Again, nothing is slowly enough to cause noticeable delays in basic typing/editing and the bottleneck is almost never on them. (I regularly work on codebase of hundreds to thousands of files or more.) So I don't spend time worrying about saving a few seconds in total per day when I can use my brain elsewhere.

latexr on Jan 23, 2024| | | [–]

You don’t have to follow a rabbit hole, these tweaks take no time at all and you can stop whenever. I used Oh My Zsh until I got fed up with the startup slowness. I open a bunch of terminal windows during the day and every one of them had a second or two of delay before I could do anything. I decided to do myself a favour and no longer put up with it. It took me a handful of minutes to figure out which plugins I actually cared about (three) and get rid of Oh My Zsh entirely. Everything about this change is better for me: it’s easier and faster to redo the setup when I do a clean install, and it’s instant in everyday use which means it’s no longer frustrating.

Ingaz on Jan 23, 2024| | | [–]

I heard a lot about slowness of oh-my-zsh but never experienced it myself.

I had slow starts when I added nvm completion to .zshrc and .. maybe conda environment but that was unrelated to oh-my-zsh

wyclif on Jan 23, 2024| | | [–]

I've also not experienced any slowness with oh-my-zsh. Now LunarVim, which is an IDE-like layer for Neovim...that's a totally different story.

pdimitar on Jan 23, 2024| | | [–]

Hmm? What about LunarVim?

wyclif on Jan 25, 2024| | | [–]

If you add more than a handful of plugins in any of these IDE layers for Neovim, like LunarVim, LazyVim, AstroNvim, &c., it can slow things down to an unacceptable level quickly.

pdimitar on Jan 25, 2024| | | [–]

That really depends. On the iTerm2 terminal? Yes, sometimes. On Alacritty and Rio? Nope, it's very snappy.

pprotas on Jan 25, 2024| | | [–]

No need to rely on your terminal to provide performance. LunarVim is very slow even though I use Alacritty, it was the main reason I stopped using it and switched to LazyVim.

wyclif on Jan 27, 2024| | | [–]

If I'm being quite honest, I think LazyVim is the more polished project. I may end up switching to that; I've been impressed by what I've seen so far (as well as using the lazy.nvim package manager).

pdimitar on Jan 25, 2024| | | | [–]

Some plugins can make it crawl, yes.

'Wansmer/symbol-usage.nvim' is one of them. I found that I didn't really need it as much so disabled it and LunarVim became much snappier.

wyclif on Jan 27, 2024| | | [–]

Yes, should have qualified it a little more by adding that it does depend very much on which plugins are currently loaded.

latexr on Jan 23, 2024| | | | [–]

> I heard a lot about slowness of oh-my-zsh but never experienced it myself.

This was years ago, no idea how it is today. But I also have no reason to go back.

> I had slow starts when I added nvm completion to .zshrc

That too, but that’s unrelated. To me that was yet another reason to stop using node altogether, I wasn’t enjoying it anyway.

JoBrad on Jan 23, 2024| | | | [–]

PowerLevel10k has quite a bit of functionality, and is more performant in my experience, giving me the best of both worlds.

https://github.com/romkatv/powerlevel10k

pprotas on Jan 23, 2024| | | [–]

While I love p10k and use it myself, note that p10k is just a theme, while ohmyzsh is a theme manager (that comes with default themes) + plugin manager + a collection of aliases + other QoL stuff.

trallnag on Jan 23, 2024| | | [–]

p10k is not just a theme, it implements a whole prompt to realize features like instant and transient prompt. For example showing your current Kubernetes namespace while you are typing a kubectl command.

sshine on Jan 23, 2024| | | | [–]

Having PowerLevel10k shortened as p10k bugs me, because "owerLevel10" is 11 characters.

BytesAndGears on Jan 23, 2024| | | [–]

Yeah I have a ton of customization including a really sweet looking prompt (that includes branch name & even git remote project name). Shortcut aliases and custom functions for everything that I use often. Atuin for Ctrl+R history searching.

All without using any “plugins” or ohmyzsh. All just within my .zshrc, and a few extra files that get “sourced” depending which computer I’m on. Only occasional copy-pasting a few things I liked from StackOverflow.

Basically instantaneous speed. Don’t even notice any performance penalties from all of the customization and styling.

I did have a performance issue early on, but I profiled my zsh startup time and saw 97.5% of my shell startup was consumed by NVM (node version manager), and another 2.4% was RVM (ruby). Switched to FNM and Chruby instead, and it was zippy.

And it’s all mine, so there are no “updates” to break anything. Throw it all in source control and you can keep improving it without risk of losing your previous working config.

sshine on Jan 23, 2024| | | [–]

Customizing my prompt was a reason to stick to zsh instead of oh-my-zsh.

But lately I've become really happy with just installing spaceship.

Sure, it doesn't look exactly like I want it to. But it shows git status.

Various features just "pop up" if I install the right things on the system.

tough on Jan 24, 2024| | | [–]

starship is the new spaceship, yo

https://starship.rs/

nickjj on Jan 23, 2024| | | [–]

Yep, I use zsh with 2 plugins. One for syntax highlighting commands and another for showing auto-suggestions. It's really fast. The rest is nearly a default zsh set up in terms of zsh configuration. Everything is documented in my dotfiles https://github.com/nickjj/dotfiles.

My prompt is a 1 liner that shows your git branch as well as coloring up $ to be red or not based on if the last command failed. Coincidentally I just released a blog post today on coloring up your prompt based on if the last command failed at https://nickjanetakis.com/blog/color-your-shell-prompt-red-i..., there's solutions for both zsh and bash.

JNRowe on Jan 23, 2024| | | [–]

Noting that you didn't solicit advice, but…

* Exporting shell variables such as HISTFILE isn't necessary, and can be unsafe. For example, if you decide to pop open unconfigured bash from within a zsh session it would intermingle its history on write.

* There is a smart keyboard subsystem that neatly manages terminal differences¹, making it much nicer compared to inserting {system,term}-specific escapes in to your config.

Hoping this comes across in the helpful spirit it was intended, not as nitpicky unwanted code review.

¹ https://zsh.sourceforge.io/Doc/Release/User-Contributions.ht...

nickjj on Jan 23, 2024| | | [–]

Thanks, I'm always open for advice.

* For shell history I don't think I've encountered that issue yet. For example if I have zsh loaded and run `bash` and then within that bash session run `whoami` and exit bash, my `history` within zsh doesn't include the whoami command, only `bash`. Is there another workflow that would produce intermingled history?

* Ah, this is likely in reference to the home / end / insert / etc. key binds I added? I think I came up with those from following a 2007 blog post[0] which I found here[1]. Do you know what the nicer versions would be for those specific keys? The docs are coming up empty with specific examples and most Google results return the escaped references.

[0]: https://blog.andrewbeacock.com/2007/08/how-to-get-home-end-k...

[1]: https://stackoverflow.com/questions/8638012/fix-key-settings...

JNRowe on Jan 24, 2024| | | [–]

For the first; Unless your bash config overrides the environment variable you've set it will use $HISTFILE from the calling shell, which is why "HISTFILE= " without the export fixes it. You can test it with:

```
    export HISTFILE=trash
    bash --norc
    echo hello
    exit
    cat trash

```

It isn't just intermingling either, bash may truncate the file depending on how it is configured too. You can see this by performing the same procedure as above but starting with 1000 lines in the trash file, bash will truncate the file to 500 lines by default on exit. It shouldn't happen in your case as you're also exporting HISTSIZE, but it can if you have a lot of multiline history events as bash treats them differently to zsh.

The point wasn't just about HISTFILE really though, very few of the shells own configuration variables are useful in child processes. (LC_* and PATH being the obvious exceptions that spring to mind.)

---

For the second; The doc I linked to above shows how to use zkbd to handle terminal differences in a clean way. Run the wizard, and then you can use the $key array as in $key[Home]. The neat thing to do with zkbd is have the wizard run on startup when it can't find its definitions file, that way you'll get correct behaviour whenever you play with a new terminal type.

Another option is to use the terminfo database¹ directly, if you trust it to be correct for your terminals. "zmodload terminfo", and then the database is available through the $terminfo array as in $terminfo[khome] or using the echoti function².

¹ https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html#The-...

² terminfo(5) contains the mappings, but they're often far less readable than the $key array. $terminfo[kpp] vs $key[PageUp], for example.

nickjj on Jan 24, 2024| | | [–]

Thanks, I'll test them out and apply the changes. It sounds like all 4 of the history env vars don't need to be exported.

JNRowe on Jan 24, 2024| | | [–]

What felt like an initial thirty second throwaway comment yesterday has turned in to a pile of replies that feel like a poorly conceived Ted talk now, forgive me for that.

The dividing line between variables that should be prefixed by export are ones that are generally useful to child processes and ones that are not.

For example, $PATH is useful and should be exported. You probably want scripts you start to have access to all the things you have installed, not just the locations of the default search path:

```
    PATH= =zsh -fc 'print -l $path'

```

$HISTFILE/$PROMPT/etc control current shell behaviour and are unlikely to be of any use to child processes executed by the shell, and do not need to be exported. Remembering, of course, that they'll be set by any new interactive shells anyway as they too will read their startup files when launched.

Oftentimes it doesn't make much difference. However, some such as $CDPATH can cause non-obvious bugs when they're exported, and some such as $HISTFILE can cause data corruption or even loss when the planets align against you.

nickjj on Jan 24, 2024| | | [–]

Hah no problem.

There was just enough time after your talk for 1 more question from the audience:

For my zshrc that you poked around in, is this issue related specifically to HISTFILE or all of the history related env vars?

JNRowe on Jan 24, 2024| | | [–]

All four of the $HIST* parameters are perfectly functional without export.

alright2565 on Jan 23, 2024| | | [–]

Someone's made a benchmarking system for zsh: https://github.com/romkatv/zsh-bench#premade-configs

Of course, their config is the best according to the benchmark (and ohmyzsh is the slowest option), but DIY configs are also covered, particularly possible performance optimizations.

nunez on Jan 23, 2024| | | [–]

100%. This is dotfiles on super easy mode. PS1 and PROMPT_COMMAND are your friends!

BossingAround on Jan 23, 2024| | | [–]

I hate very few things, but PS1 is one of them.

Would recommend using a PS1 generator, e.g. [1].

[1] https://bash-prompt-generator.org/

drcongo on Jan 23, 2024| | | | [–]

Nobody is friends with PS1.

wesapien on Jan 24, 2024| | | [–]

Just pull down the extensions from the source repo and source them in your zshrc.

vorticalbox on Jan 23, 2024| | [–]

I used ohmyzsh with powerlevel10k/powerlevel10k[0] for years though recently i've settled on fish [1]

[0] https://github.com/romkatv/powerlevel10k [1] https://fishshell.com/

mplanchard on Jan 23, 2024| | [–]

Yeah I tried zsh a few times and never really thought it gave me that much relative to my existing bash config.

Fish on the other hand has stuck, and I'm still discovering nifty new built in features, like the fact that if you type `kill`, you can tab-complete on process names, so like if I want to kill emacs, I can type `kill ema ` and select from the following:

```
    > kill ema
    3296  (.blueman-applet)  3595  (.blueman-tray-w)  9324  (emacsclient)  9327  (emacs)  9557  (emacsql-sqlite)

```

If there's only one match it completes the PID for you, and of course if you start typing a PID and press tab it shows the process names along with the potential completions.

I use starship for prompt customization, which is nice because my config transfers just fine from bash over to fish.

JNRowe on Jan 23, 2024| | | [–]

FWIW, that is also the default behaviour of zsh's standard completion subsystem for kill. You can try it yourself: "zsh -f" to get a shell without reading a fancy config, start compinit, "kill ".

You can even disable verbose mode via zstyle, should you be the type of person that likes a simple pid list like bash's completion project provides. To me this level of customization is the main feature zsh provides, but not everyone incessantly turns every knob they see.

mplanchard on Jan 23, 2024| | | [–]

Nice! It's super useful in fish, good to know it's in zsh too

wyclif on Jan 23, 2024| | | | [–]

What I do is use zsh as my default shell and use oh-my-zsh, but keep a very simple config for my ~/.bashrc, something like:

```
    [ -f ~/.fzf.bash ] && source ~/.fzf.bash

    source /Users/wyclif/.config/broot/launcher/bash/br

```

This gives me the best of both worlds.

evnix on Jan 23, 2024| | | [–]

I start using fish, really like its feature set, but then have to give up and switch back to zsh when I want to get anything done. Unlike zsh, Fish isn't compatible with bash syntax, so a lot of existing scripts and software just doesn't work right. Even today people write scripts as if bash already exists and they seem to always target it. I wish fish had some form of compatibility layer.

jackhalford on Jan 23, 2024| | | [–]

Are sourcing bash scripts in a fish shell? If you can either run bash ./xyz or add the shebang #!/bin/bash to run scripts with the intended interpreter

osmsucks on Jan 23, 2024| | | | [–]

I've been using it for years and most things I need nowadays just work (i.e. have Fish support out of the box).

For all the rest, perhaps give https://github.com/edc/bass a try.

mulmen on Jan 23, 2024| | | | [–]

Can you add a shebang and make the script executable or just run the script as an argument to the bash program?

arbitrandomuser on Jan 23, 2024| | | [–]

This . You just have to use fish for live interacting with the system aaand its great ,for everything else you can stick to bash.

Don't even change your default shell with chsh ,rather just point your terminal emulator to launch fish

petepete on Jan 23, 2024| | | | [–]

I recreated my zsh setup in fish with about 10% of the config and just one plugin (fzf.fish).

Nearly everything I want, fancy autocompletion, syntax highlighting, git-aware prompt just worked out of the box.

markstos on Jan 23, 2024| | | | [–]

Fish runs bash scripts just fine, as it does any script with a shebang line. IT is increasingly compatible with random CLI commands copy and pasted from the internet.

For those that don't work right away, just type `bash` to enter bash shell, run the command return back to Fish.

If a significant part of your day is spent copying CLI command from the internet, then yes, perhaps Bash is a better choice for you.

eviks on Jan 23, 2024| | | | [–]

fish has a compatibility layer, and existing scripts still can use bash

cybrox on Jan 23, 2024| | | [–]

Can you summarize what made the switch worthwhile for you?

I've been using zsh/omz with a customized powerlevel10k for years now and I see fish mentioned all the time but I didn't really find a compelling reason to try it out for myself.

hiAndrewQuinn on Jan 23, 2024| | | [–]

My niche use case is that since fish comes out of the box with a whole bunch of very nice features (syntax highlighting on the shell, really good autocompletion) it's easy for me to stick it into the set of shell scripts I use to turn a new Ubuntu VM into a dev productivity machine. [1]

I could probably get Zsh to do all the same stuff I would want fish to do out of the box, but it would make reading through and reasoning about the shell scripts more difficult for third parties to audit, who may not be familiar with either tool before they try it.

[1]: https://github.com/hiAndrewQuinn/shell-bling-ubuntu

TheRoque on Jan 23, 2024| | | | [–]

You just install it and it works. I change devices, or wipe out my devices often enough that just having a familiar shell installed in one line feels comfy. I usually don't customize things a lot, I pick something with good default and rarely change anything on it. I don't want to bother downloading plugins and addons, or fonts, or themes, just for a command interpreter.

acdha on Jan 23, 2024| | | | [–]

For me it came down to speed and maintenance. Fish is incredibly fast and I spend almost no time configuring it, so it’s trivial to bring up on a new system and I don’t have to exercise self-control to avoid tweaking it (that’s a personal failing, not other shells).

theshrike79 on Jan 24, 2024| | | | [–]

It's easy to install. I used to have some fisher plugins, but gave up on those since none of them were really essential.

When I set up a new computer I can just install fish and starship prompt and I'm mostly done. My fish configuration file is just aliasing and sourcing configs from other software, it's been a while since I had to touch it.

vorticalbox on Jan 23, 2024| | | | [–]

only a few things that are probally also possible in zsh

fish functions are super easy to create on the fly from a command updating $path is fish_add_path {path here} setting global variable is easy set -Ux FOO bar adding -g makes it global

most of these require me to update my .zshrc and source ~/.zshrc as far as i am aware

cvdub on Jan 23, 2024| | | [–]

fish has by far the best auto-completion out of the box. That’s what sold me.

And the website is amazing. “Finally, a command line shell for the 90s”

mrd3v0 on Jan 23, 2024| | | [–]

Tide is as close to powerlevel10k as one can get in Fish.

https://github.com/IlanCosman/tide

Keyframe on Jan 23, 2024| | | [–]

zsh, oh-my-zsh, p10k, fzf, and as of recently zsh-autosuggestions plugin for oh-my-zsh is what I ride on. I keep hearing about fish, and I see what it's doing but I'm not sure what it would bring to the table compared to the setup?

hibbelig on Jan 23, 2024| | | [–]

So fish comes with nice defaults. It could happen that you have a complicated zsh setup, then migrate to fish and you find the defaults are fine.

The fish scripting language is nicer (more logical) than the zsh one. That's because zsh needs to be Bourne-ish for historical reasons, and fish has decided to deviate from it. Existing sh, bash, zsh scripts will continue to work just fine. You can write new scripts in fish, or keep writing scripts in zsh or whatever.

cbarrick on Jan 23, 2024| | [–]

I never understood how omz was useful.

Zsh already has a module system (autoload), a prompt framework (promptinit), and Git integration (vcs_info) builtin.

I have a pretty extensive Zsh setup in vanilla Zsh: https://github.com/cbarrick/dotfiles

Ingaz on Jan 23, 2024| | [–]

You're correct: omz adds not a lot to vanilla zsh.

It consists of: - collection of plugins/themes - auto update - way to customize them

Everything could be done directly in .zshrc, it's just a bit more convinient

sshine on Jan 23, 2024| | | [–]

I used zsh for a few years before oh-my-zsh became a thing.

I have to admit that I don't find it more convenient.

It takes an ecosystem where things have a way of working, and establishes new conventions on top of those using a new set of environment variables. So if you know zsh, you don't know oh-my-zsh.

A vanilla zsh will feel very bare.

A vanilla oh-my-zsh will feel very feature rich.

If you end up configuring zsh anyways, I don't see the point at all.

yla92 on Jan 23, 2024| | [–]

Recently, I moved off from oh-my-zsh after many users, to vanilla zsh with https://starship.rs, mainly due to the loading speed (used https://github.com/romkatv/zsh-bench to measure the speed).

Still wanting to try out fish and hopefully soon!

_aaed on Jan 23, 2024| | [–]

If one of a product's main features is that it's written in Rust, it probably doesn't have anything unique compared to the competition

rpigab on Jan 23, 2024| | | [–]

Which is a major selling point. We do not want anything unique.

Ripgrep accept most basic flags that grep uses and is way faster (when searching for code under VC), and that makes using it very convenient, even before considering the features on top.

I would prefer that you also write your HN comments in Rust, if that's possible, for better performance and safety. In the future, there will only be Rust. You have to accept Rust into your life.

bitwize on Jan 23, 2024| | | | [–]

A memory-safe, fearlessly concurrent version of $thing is imho a huge win in and of itself.

Soon a Rust userland will be table stakes.

markstos on Jan 23, 2024| | | | [–]

Fish has been great for years.The Rust rewrite will help the devs catch issues earlier in development. Hardly a main a feature.

The awesome level tab-completion and auto-completion are the firs things to notice about Fish. Also, overall cleaner syntax and a several nice built-in commands that don't ship with Bash.

mplanchard on Jan 23, 2024| | | | [–]

Not sure if you're talking about starship or fish, but starship is by far my favorite prompt customization tool, regardless of what language it's written in. It works across bash, zsh, fish, and others, so you can pretty easily get the same prompt in any shell on your system. It's easy to tweak as needed, but is pretty great out of the box.

theshrike79 on Jan 24, 2024| | | [–]

Moving to starship as prompt stopped my prompt bikeshedding habits immediately.

radimm on Jan 23, 2024| | [–]

All good until your ZSH gets heavyweight and slow. Started using fish and never looked back

cal85 on Jan 23, 2024| | [–]

I've never noticed slowness in OMZ, or really any shell. Or at least, when something feels slow I've always assumed it's the application I'm using, or network congestion, not the shell itself. In what situations do you notice a shell being slow?

brandall10 on Jan 23, 2024| | | [–]

Initializing a new session is not instantaneous. Even on my M3 Max it probably takes a couple hundred milliseconds, which is fine.

When I first tried it over a decade back, IIRC on an 11" Air, each new session was probably closer to a couple seconds. I recall there were a couple plugins in particular that were major bottlenecks. Replaced those and got the init speed to about half that but it annoyed me enough to do a clean zsh setup.

jeroenhd on Jan 23, 2024| | | [–]

OMZ is fast even on my phone.

It turned slow for a whole after I installed anaconda. If you use conda and your shell is slow, try commenting out the code that loads conda, because it's probably that.

nvm likes to slow things down too. Not as bad as conda, but I did add some code to delay load it.

Do you know how fish would prevent getting slowed down by external scripts in its configuration file? Or does it just not support those scripts perhaps?

mitemte on Jan 23, 2024| | | [–]

I switched from nvm to fnm a few years ago and have never looked back. Zero performance issues and it supports .nvmrc files.

https://github.com/Schniz/fnm

eigenvalue on Jan 23, 2024| | | | [–]

It's wild to me how slow conda is. Just in ordinary day to day use, with nothing weird, you sometimes need to wait insane amounts of time, even on incredibly fast systems. Whatever they're doing, it's wrong and bad.

Ingaz on Jan 23, 2024| | | | [–]

I had exactly same experience: nvm and conda. Both are unrelated to oh-my-zsh completely: they were configured in .zshrc directly

Hamuko on Jan 23, 2024| | | [–]

I just skipped over zsh since I didn't want to spend time configuring it, as fish is pretty good out of the box.

linsomniac on Jan 23, 2024| | | [–]

Ditto. Added atuin.

kekebo on Jan 23, 2024| | | [–]

ZSH + Zimfw + Powerlevel10k is probably the fastest "bling"-y shell I managed to put together. Would usually smoke Fish, but I haven't compared recently

rixrax on Jan 23, 2024| | | [–]

I backtracked all the way to Bash. Because I seem to write some amounts of bash scripts, it seems living inside bash is helpful. And it's really not much I feel like I am missing in my use from zsh (or fish). Bash even supports CTRL+R for history with search nowadays.

markstos on Jan 23, 2024| | | [–]

I write bash scripts but use Fish interactively.

Yes, I've had to get clear where they differ, but the Fish experience is that much better that it seems worth it.

I've considered replacing more my bash scripts with Fish scripts, but it seems Fish has a slower start start-up time for scripting (not that it matters most of the time) and is more designed for interactive use.

Levitating on Jan 23, 2024| | | | [–]

I only script in fish anymore, all my devices use fish anyway (it's even pre-installed on steam deck).

swah on Jan 23, 2024| | | [–]

Started using fish, moved back in 3 minutes. Remembered I have this awesome shortcut in Zsh where I type what I need to do, hit cmd+G, and some ChatGPT replaces my input with an example command.

peebeebee on Jan 23, 2024| | | [–]

oooh, what plugin is this?

swah on Jan 23, 2024| | | [–]

https://github.com/TheR1D/shell_gpt?tab=readme-ov-file#shell...

Levitating on Jan 23, 2024| | | [–]

My only issue with fish is that it has had a standing issue[1] for over 12 years where functions and blocks cannot be backgrounded. This makes backgrounding a series of commands in a script nearly impossible.

[1]: https://github.com/fish-shell/fish-shell/issues/238

FlyingSnake on Jan 23, 2024| | | [–]

Came here to say this. Fish shell is such a fresh beeeze compared to zsh.

Now it’s even rewritten in Rust!

csmattryder on Jan 23, 2024| | | [–]

You've got to install Fisher, then get z, sponge and a few others from the awsm.fish list.

Then you get trapped by the utility and struggle when you land on some remote server's bash shell.

https://github.com/jorgebucaran/fisher

https://github.com/jorgebucaran/awsm.fish#readme

Jackevansevo on Jan 23, 2024| | [–]

The defaults it ships out of the box makes the shell actually usable. Unsure I could ever go back to a regular bash/zsh prompt.

A lot of people will tell you this is slow and you've got to use X,Y,Z instead. If you're new, I'd strongly recommend just sticking with this, it's much easier to configure.

enw on Jan 23, 2024| | [–]

The following goes a long way:

```
    setopt PROMPT_SUBST
    HISTFILE=~/.zsh_history
    HISTSIZE=100000
    SAVEHIST=100000
    PROMPT='%B%(?..%F{red}%?%f )%F{blue}%~ %F{green}%#%f%b '
    RPROMPT='%B%F{red}$(git branch --show-current 2> /dev/null)%f%b'

```

And if you want autosuggestions:

```
    brew install zsh-autosuggestions

```

Then add the following to your ~/.zshrc:

```
    source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
```

Brajeshwar on Jan 23, 2024| | [–]

Hey, I must have copied something similar from somewhere but yes my first base setup of my shell is

```
  PROMPT='%{%F{red}%}%~ %{%F{yellow}%}% › %{%F{reset_color}%}%'

```

Anything after (besides the path and the GPG setup) that is an add-on that I can remove and still function well. I've learned to live without Git info. But this is very personal and I have not been into active development for quite a while.

msephton on Jan 23, 2024| | [–]

PSA: simply installing this won't get you many benefits until you read about what it can do and then make an effort to use those things in your workflow.

turblety on Jan 23, 2024| | [–]

Any recommended reading? I found a cheatsheet [1] which seems useful, but there's not that much in there.

1. https://github.com/ohmyzsh/ohmyzsh/wiki/Cheatsheet

Zizizizz on Jan 23, 2024| | [–]

Zsh autosuggestions Zsh syntax highlighting Fzf-tab

Paired with zoxide and fzf for the zsh keyboard shortcuts are all I need to be very productive.

Starship.rs is very useful as well as a theme but pure and pl10k are also great.

eigenvalue on Jan 23, 2024| | [–]

I use and like omyzsh, but find it super annoying how it deals with updating. It either nags you constantly to update, or if you set it to "auto," then it's constantly spamming you about how it's updating, and when you create a new shell session (say, in tmux), it causes significant lag before you can use the new shell and pollutes the console with tons of output. There has to be a better way, like some optional mode that just runs an update service in 3am silently using systemd.

wirrbel on Jan 23, 2024| | [–]

Grml zsh is all I need https://grml.org/zsh/

argulane on Jan 23, 2024| | [–]

grml is great! It has pretty much everything you need. grml config file is also quite readable and you can learn quite a lot from just reading it.

wirrbel on Jan 23, 2024| | | [–]

I actually never used the live bootable cd of the grml project, just the zsh config

sshine on Jan 23, 2024| | [–]

For comparison, here is my Zsh configuration in NixOS:

```
  {
    programs.starship = {
      enable = true;
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
      enableGlobalCompInit = true;
      syntaxHighlighting.enable = true;
      syntaxHighlighting.highlighters = [ "main" "brackets" ];

      histSize = 100000;

      # See `man zshoptions` for more details.
      setOptions = [
        # Remove duplicates continuously from command history (preserve newest entry).
        "HIST_IGNORE_DUPS"

        # Instantly share command history between all active shells.
        "SHARE_HISTORY" # Alternative to: "APPEND_HISTORY", "INC_APPEND_HISTORY",

        # Disable ^S and ^Z for less accidental freezing.
        "FLOW_CONTROL"

        # Save timestamp and duration of each command in command history.
        "EXTENDED_HISTORY"
      ];

      shellAliases = {
        rm = "rm -iv";
        ls = "ls -F --color=auto";
        gs = "git status";
        gd = "git diff";
        gdc = "git diff --cached";
        gap = "git add -p";
        gl = "git log";
        gpr = "git pull --rebase";
      };

      interactiveShellInit = ''
        bindkey '^[[7~' beginning-of-line
        bindkey '^[[8~' end-of-line

        bindkey '^R' history-incremental-search-backward

        eval "$(starship init zsh)"
      '';
      };
  }

```

My .zshrc used to be bigger, but I've slimmed it down to see what I actually use from it.

poochkoishi728 on Jan 23, 2024| | [–]

One time, I was cowboy coding and ended up writing `grhh` (`git reset --hard`) and hit enter before I realized that it was a mistake.

ivanjermakov on Jan 24, 2024| | [–]

Reflog to the rescue: https://git-scm.com/docs/git-reflog

KolenCh on Jan 24, 2024| | [–]

Zprezto is a good alternative which is also faster. I eventually migrated to zim because of its minimalist approach.

I think starting from Oh My Zsh or zprezto can be a good choice. Once you get a feel of what zsh can accomplish, eventually probably you’ll one day find it too slow and/or too complicated and then would switch to something like zim to only load the things you know is useful from then.

highmastdon on Jan 25, 2024| | [–]

Do yourself a favour and install fish-shell with starship.rs and call it a day. Make sure to put everything prompt related in a `if status --is-interactive` block. Blazing fast versatile fancy prompt and interactive human friendly shell. What does a man need more?

joejag on Jan 23, 2024| | [–]

I followed this advice and my shell went from 1530ms to 35ms startup time.

Main culprits were language switchers (nvm, jabba, pyenv). Which I moved to lazy loading.

If I drop the ohmyzsh plugins startup time is 11ms. But, I want some quality of life.

There's a nice benchmarking command in the article if you want to test yours:

for i in $(seq 1 10); do /usr/bin/time $SHELL -i -c exit; done

wrboyce on Jan 23, 2024| | [–]

That benchmark command isn’t great: https://github.com/romkatv/zsh-bench#how-not-to-benchmark

dogmayor on Jan 23, 2024| | [–]

I prefer sheldon[1] for the few plugins I use

[1] https://github.com/rossmacarthur/sheldon

MissTake on Jan 23, 2024| | [–]

I use omz primarily with the Kubernetes addons - which are now integral to my existence.

Does fish support something similar? If so then I could be encouraged to give it a whirl.

h4ch1 on Jan 23, 2024| | [–]

zsh autosuggestions has been pretty slow for me compared to fish out of the box, switched a year or so back and have been pretty happy. maybe something has changed now :thinking-emoji:

oh-my-fish is pretty much similar in capabilities and has a good assortment of themes.

All I used that came with zsh were git shortcuts like gc -m "comment", gst for git status which i just recreated in my fish config.

firexcy on Jan 24, 2024| | [–]

These days I stick to a minimal profile for the default shell (zsh on macOS and bash on Linux), adding no further than some aliases. When I need more “friendly” interactive features I launch fish which is… friendly and interactive, and exit when I’m done. Thus I get the best of both worlds.

Charlie_32 on Jan 23, 2024| | [–]

I'm a developer of 10 years, and use the command line for Git, Brew and a few other things, though I'm normally an IDE developer. I believe the CL is as powerful as everyone says, but what are some useful things I can use it for? I use Zsh on a Mac some of the time.

d0mine on Jan 23, 2024| | [–]

"Always Bet on Text"

- CLI encourages automation (shell commands are easier to repeat/parametrize then GUI steps) - shell instructions are more git friendly than screenshots (even if a process can't/shouldn't be automated. Commands are easier to document in a reusable/updatable way) - CLI can be used to run tests in a way similar how CI does it (more reproducible)

Command line tools are easier to extend/combine with existing pipelines (rg,jq,xargs): read input from stdin/write output to stdout, report on stderr, return non-zero code on error. It enables you to create adhoc tools that you wouldn't bother otherwise (unrelated: LLMs also have this property by making your skill set much broader (though very shallow with current LLMs)). Shell also has Forth-like property (compose with: retry, timeout, setuid, exec, xargs, env, ssh, etc) https://www.oilshell.org/blog/2017/01/13.html

pletnes on Jan 23, 2024| | | [–]

Rename hundreds of files at a time. Find stupid errors in GB sized csv/json/.. data files. Automate git bisect. Automate workflows by writing a short loop or 3 commands in a row you can easily repeat. Down/upload big datasets. Convert text files any way you can think of.

jay-aye-see-key on Jan 23, 2024| | | [–]

The two things you can do in the shell you mostly can’t do elsewhere is compose arbitrary commands and store custom commands.

For #1 this blog post has some good examples of quickly chaining together commands (though personally I rarely use xargs) https://drewdevault.com/2020/12/12/Shell-literacy.html

For #2 once you’ve got a command you like, maybe one that generates a metric, you can now re-run it with ease from your history, saved text file, or an alias. You could also share it with teammates.

Please correct me if there are other ways to achieve the above, shell is the only way I know

pjmlp on Jan 23, 2024| | | [–]

Programming languages REPL environments.

reactordev on Jan 23, 2024| | | [–]

Colorful prompt with context information, powerline glyphs, autocomplete, command highlighting, easy navigation through strings, plugins and a plugin ecosystem that extends your shell like crazy

PrimeMcFly on Jan 23, 2024| | | [–]

> but what are some useful things I can use it for?

I mean, surely you already know?

Anything where feeding input between different tasks, or where you want to use regex, or similar things the cl will be superior.

smcleod on Jan 23, 2024| | | [–]

10 years in tech and you haven’t optimised your shell?

Brajeshwar on Jan 23, 2024| | | [–]

20+ years in tech and these days, the first thing that comes to my mind is usually, “Can I walk out of this?” :-)

The idea is to be able to use any computer/system/devices easily instead of one perfectly.

markstos on Jan 23, 2024| | | [–]

I strive to speak multiple languages, but I think it still worthwhile to be really good at my primary language of English.

Same with computers and servers. I interact with a lot of them, but my primary computer that I use >80% of the time is worthwhile to optimize with some tooling that's not available on all the others.

smcleod on Jan 23, 2024| | | | [–]

Gosh, I couldn’t think of anything worse than having to optimise myself for generalist systems

kjellsbells on Jan 23, 2024| | | [–]

Might be a generational thing.

Some folks grew up on systems that could fail at any time and leave them with nothing but the tools in /sbin to fix it with. No /usr, no bash/zsh, just sh and vi if you were lucky. You learn to love the cool new things, but you still have a mental bag packed with fsck and ed in case you need to bug out.

It's silly, really because no systems are like that any more, but the things you learned at 2am when you were 22 tend to stick with you.

smcleod on Jan 23, 2024| | | [–]

Perhaps, I’ve been in tech 18+ years though. Cut my teeth on Solaris, AIX, Unix, Linux etc… the good old days!

pjmlp on Jan 23, 2024| | | | [–]

Coding since 1986 and I touch the shell as much as I have to, If I cared that much I would still be using MS-DOS, and UNIX without X.

Symbiote on Jan 23, 2024| | | [–]

When you need to rename 5000 files from abcd_small.jpg to abcd.jpg, how do you do that?

```
  rename s/_small// *_small.jpg

```

When you have the string ABCD_XYZ in 50 files but you need to change it to DEFG_UVW, how do you do that?

```
  perl -pi -e 's{ABCD_XYZ}{DEFG_UVW}' **/*(.)

```

When you need to move all the files ending '.png' into the directory 'PNG', and all the ones ending '.jpg' into 'JPG', how do you do that?

```
  mkdir JPG PNG;
  for i in *.png *.jpg; mv $i $i:e:u
```

JNRowe on Jan 23, 2024| | | [–]

As we're in a zsh story, I'll point out it comes with a clever file renaming interface out of the box¹. It allows full access to all the advanced glob operators zsh provides too².

¹ https://zsh.sourceforge.io/Doc/Release/User-Contributions.ht...

² https://zsh.sourceforge.io/Doc/Release/Expansion.html#Filena...

eggdaft on Jan 23, 2024| | | | [–]

On the second one - if that’s in code than a good IDE will not only do it with a single keypress, but will also (optionally) do it intelligently eg change only in the code, not the comments, show you a browseable preview, and offer undo should you get it wrong.

I like the shell but I also think IDEs are underrated.

pjmlp on Jan 23, 2024| | | | [–]

There are GUI tools that do that, and thankfully most scripting languages have a REPL.

Symbiote on Jan 23, 2024| | | [–]

I'll bet it takes longer to find and use a GUI tool for these.

And a shell is a REPL.

pjmlp on Jan 23, 2024| | | [–]

You bet wrong, because naturally approaching 50y, I have my tools for quite some time, for the stuff I care about, not random examples on the Internet.

A UNIX shell is a very bad approximation of a real programming language REPL.

It is no accident that sh scripts turn into Perl, Python, Tcl, Lisp,... when one wants to keep sanity.

cnity on Jan 23, 2024| | | | [–]

X years in tech and you haven't Y.

Pick any X and Y that maximises your ability to feel superior, I suppose.

smcleod on Jan 23, 2024| | | [–]

Nothing to do with being superior (seriously - it’s just a shell?) - was just surprised (if that’s ok with you).

cnity on Jan 23, 2024| | | [–]

Honestly, fair enough. I probably misread your tone!

smcleod on Jan 23, 2024| | | [–]

No worries, it happens and could have just as easily been how I worded it. :)

imdsm on Jan 23, 2024| | [–]

Been using it for years now, can't fault it, but I don't do too much with it

peauc on Jan 23, 2024| | [–]

I would actually recommend using fish with budspencer theme which is really great https://github.com/oh-my-fish/theme-budspencer

flaxton on Jan 23, 2024| | [–]

Loading time is not an issue for me. I run tmux so my sessions stay alive and performance is very quick. M2 MacBook Air with 16GB RAM, using Warp terminal. Using OMZ with Dracula Theme and mosh for remote servers.

andirk on Jan 23, 2024| | [–]

Am I the only one with almost nothing custom in my bash/zsh?

rnd0 on Jan 23, 2024| | [–]

I don't either. -hell, since I found out that "set -o emacs" gives me history and autocompletion I go even further and usually only use /bin/sh on NetBSD.

I'm not sure what the use case for zsh and fish are, but I'm guessing it's different than mine.

(edit/update: apparently, judging by a quicky netbsd 10 vm install, you don't even need to explicitly "set -o emacs". /bin/sh does it by default)

encom on Jan 23, 2024| | | [–]

No, I've used vanilla Bash for two decades now. The only thing I change is make autocomplete not case sensitive, and set up an ls alias

```
    alias ll='ls -lvX --almost-all --group-directories-first --human-readable'

```

I can sit at any machine and feel right at home.

al_borland on Jan 23, 2024| | | [–]

I add in a folder to my path where I keep scripts I wrote, that’s about it.

ivanhoe on Jan 23, 2024| | [–]

OMZ and zsh are great in many ways, but I still miss my CTRL + W from the bash, deleting the whole word regardless of the chars...

JNRowe on Jan 23, 2024| | [–]

Like practically everything zsh, it can be configured. The select-word-style zle widget¹ ships with zsh, and has a bash compatible setting(among others). The interface is super powerful, and given that you can change it in individual zle widgets you can make it context aware if you wish too.

¹ https://zsh.sourceforge.io/Doc/Release/User-Contributions.ht...

vault on Jan 23, 2024| | | [–]

works perfectly fine for me. maybe you have misconfigured your terminal application?

alxndr13 on Jan 23, 2024| | [–]

funny coincidence, just finished re-modding my zsh.

Removing omz, adding antidote and starship. feels (and measureably is) faster and snappier.

dsego on Jan 23, 2024| | [–]

One neat alternative is ohmyposh.dev

blentrop on Jan 23, 2024| | [–]

One option I really like liquid prompt[0]. Simple design which just shows the info I need without getting on my way

[0] https://github.com/liquidprompt/liquidprompt

dogmayor on Jan 23, 2024| | | [–]

ohmyposh is a prompt theming engine, not a plugin manager. But it is a great way to find a good prompt or create your own.

nunez on Jan 23, 2024| | [–]

Note that most of ohmyzsh can be done in pure Bash

mbrumlow on Jan 23, 2024| | [–]

Just use fish.

funkyreg1 on Jan 23, 2024| [2 more]

[flagged]

jackhalford on Jan 23, 2024| [–]

Are you ok man?

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### Aha! Now I know that nvm was slowing my shell startup down. Now I've reconfigure... | Hacker News
**URL:** https://news.ycombinator.com/item?id=44627354

```text
Aha! Now I know that nvm was slowing my shell startup down. Now I've reconfigure... | Hacker News

Aha! Now I know that nvm was slowing my shell startup down. Now I've reconfigured .zshrc to lazy-load nvm, and everything's snappy:

```
  zstyle ':omz:plugins:nvm' lazy yes
```

You should try switching to mise. I tried fnm too which was an improvement but mise does the same as fast and supports essentially every language

Definitely Mise! I was an asdf user for a couple of years and Mise was such a nice replacement. I have to juggle several other languages, and each having its own tool for tool version management was a non-starter.

Just use fnm, I like it much better

Cool! Also, there's a zsh wrapper for nvm:

Same. I switched to fnm.
```

---

### I wasn't actually aware of the impact. I measured the zsh startup time locally (... | Hacker News
**URL:** https://news.ycombinator.com/item?id=48446789

```text
I wasn't actually aware of the impact. I measured the zsh startup time locally (... | Hacker News

I wasn't actually aware of the impact. I measured the zsh startup time locally (with mvn active and commented out) and it indeed makes a difference (.39s -> .08s). Not that I would have noticed that without measuring :) - yes I'm an old geezer.

Thank you for the recommendation, I might then also be able to ditch sdkman as well.

With zsh i set up nvm to lazy load, so I don't pay for it when I don't use it (I'm a C++ and Rust dev, but I occasionally need to run js stuff from other team members).

I can strongly recommend lazy loading in zsh in general, I use it for pyenv too (which is also slow to load, but I write Python maybe every other week or so only).

The way to do this is to use the autoload functionality in zsh and have the autoloaded script replace itself with the real shell init code for the tool in question.
```

---

### How long does it seem to take to open a new terminal and reach a working shell? ... | Hacker News
**URL:** https://news.ycombinator.com/item?id=44202358

```text
How long does it seem to take to open a new terminal and reach a working shell? ... | Hacker News

How long does it seem to take to open a new terminal and reach a working shell?

Your hardware might be fast enough that it's negligible, but several years ago (maybe 2018-19ish?) I noticed my shell startup was getting sluggish and traced a large fraction of it back to the time bash took to load many lines into history.

I still like keeping it all, so I wrote something to dump it into a database as I go but then truncate working histories to something shorter (500, I think).

Instantaneous. bash might just be slow here; I'm using zsh.

```
  $ time zsh -i -c 'exit'
  zsh -i -c 'exit'  0.03s user 0.02s system 100% cpu 0.055 total
```

Are you sure it's loading history in there? My .zsh_history isn't completely empty, and when I run the same with 'history' swapped for 'exit' it doesn't print anything. (But this might have something to do with macOS default shell profile stuff.)

Actually, this seems like an interesting question. I don’t really see any reason why a shell must load the history file before the user starts typing. I mean, I usually don’t ^r immediately, so to speed things up it could:

* Load asynchronously

* Only have a barrier if I reverse-search.

Might be over-engineered, though.

zsh may very well be doing this, especially for any de-duplication index.

Not confident, no. But even running an interactive zsh manually and exiting as fast as humanly possible is within the same ballpark, modulo human reaction times.

```
  $ time zsh
  $ ^D
  zsh  0.14s user 0.04s system 80% cpu 0.219 total

```

It's just not an obstacle to spawning a new shell and using it.

A way to ensure the zsh invocation behaves as a typical interactive shell is:

```
  time zsh --login -c 'logout'

```

Note use of logout instead of exit. In this context, logout ensures whatever combination of flags used results in a login shell.

See zshbuiltins(1).

On par with the first time.

```
  $ time zsh --login -c 'logout'
  zsh --login -c 'logout'  0.03s user 0.01s system 99% cpu 0.037 total

```

Whenever I've had noticeably slow zsh startup times in the past, it was almost always some plugin/extension doing something very dumb (e.g. stuff like full 'git status' in a large repo -- just takes time); not the history management.

> On par with the first time.

This was my experience as well. The --login flag was recommended in order to address concerns raised by @abathur.

> Whenever I've had noticeably slow zsh startup times in the past, it was almost always some plugin/extension doing something very dumb (e.g. stuff like full 'git status' in a large repo -- just takes time); not the history management.

Great point.

Unfortunately, my limited research suggests tracking down which plugin or extension is the root cause is a manual effort starting with the contents of the canonical zsh initialization files (often named .zlogin, .zprofile, .zshenv, and .zshrc).

nvm plugin used to be really bad!

i think you can debug-trace loading time putting some commands on your zshconfig

Is .14s noticeable? That’s more than a couple frames at 60fps.

I mean, this might seem really bizarre to worry about, but some folks use tiling window managers and just expect to immediately start typing once the “new terminal” key is hit…

Actually this has been slightly annoying me lately after making my system pretty. I added some fancy compositor stuff and now if I do “open terminal,” “exit” the computer complains that it doesn’t know what xit means. Not a big enough problem to fix though.

Edit: huh, actually playing with it this seems to be 99% the fault of the terminal emulator anyway, not the shell or my silly special effects.

> Is .14s noticeable?

Unless the system is under memory pressure, most shell initialization will read from in-memory OS file caches and not be noticeable as you note.

Where significant delays are often seen is when a seemingly innocuous extension uses network-based or some other heavy file system I/O commands (such as a "find $HOME -type f" type of thing).

Even under memory pressure, it's not a ton of SSD IO time (e.g., mine is 5 MB).

This is why I switched to `fish`. Customizing zsh to achieve feature parity with fish (along with the tide prompt) made zsh veryyyy slow. It's entirely possible that there's some sort of optimized loader for zsh out there that ameliorates this, but I just couldn't be bothered.

The 0.14s includes me noticing zsh has started and typing ^D.

```
    time zsh -i -c 'exit'
    zsh -i -c 'exit'  0.33s user 0.31s system 97% cpu 0.658 total

```

Yeah... I've definitely got something going on here.

The only time I've ever had shell startup time be significant is when loading fancy shell rc stuff (oh-my-zsh is the most infamous but there are many others)

Unfortunately I've hit some obscure bug with exactly when `HISTFILESIZE` is applied, and had some shells truncate all my history undesirably. There are also problems with reading history if the timestamp format changes.

Just put them in files, like month per machine/mpount per shell (bash, csh, etc). Then the shell will only load the current month's history. You can use grep of the files and easily narrow down what to search in.

Sure! Something date-based is a simple way to handle perpetual storage while keeping the active history set from over-growing.

I did anything at all because the default shell profiles in macOS can cause history loss, and I'd found my last straw. I put them in sqlite because--if I was bothering to build something bespoke--I wanted to track more command-time context to build tooling around later. (Including to play with some ~curation ideas.)

I might have decided to just use Atuin if it existed at the time, but I did it three years and change before its first release. (There were maybe 5 or 6 barely-used public examples of this idea on GH at the time, but none tracked everything I wanted among other issues.)
```

---

### I have had this snippet in my .zshrc for years, autoload -U compinit && compinit... | Hacker News
**URL:** https://news.ycombinator.com/item?id=40128826

```text
I have had this snippet in my .zshrc for years, autoload -U compinit && compinit... | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

bongobingo1 on April 23, 2024| parent| context| favorite| on: Carapace: A multi-shell completion library and bin...

I have had this snippet in my .zshrc for years,

```
    autoload -U compinit && compinit
    {
      # Compile the completion dump to increase startup speed. Run in background.
      zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
      if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
        # if zcompdump file exists, and we don't have a compiled version or the
        # dump file is newer than the compiled file
        zcompile "$zcompdump"
      fi
    } &!

```

Using `zmodload zsh/zprof`, I can see about 50% (16ms) of my start up is compinit (its about 28ms without the `zcompile`).

Do you have any pointers for the "load on tab" idea? I didn't turn up any good results in DDG and LLMs were just hallucinating.

BTW I believe `-C` will disable some cache checking, caching is enabled by default

> To speed up the running of compinit, it can be made to produce a dumped configuration that will be read in on future invocations; this is the default, but can be turned off by calling compinit with the option -D.

> ...

> ... The check performed to see if there are new functions can be omitted by giving the option -C. In this case the dump file will only be created if there isn't one already.

bongobingo1 on April 24, 2024| [–]

Unable to edit, but this is how I handled lazy loading the completions

```
    {
      # load compinit and rebind ^I (tab) to expand-or-complete, then compile
      # completions as bytecode if needed.
      lazyload-compinit() {
        autoload -Uz compinit
        # compinit will automatically cache completions to ~/.zcompdump
        compinit
        bindkey "^I" expand-or-complete
        {
          zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
          # if zcompdump file exists, and we don't have a compiled version or the
          # dump file is newer than the compiled file, update the bytecode.
          if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
            zcompile "$zcompdump"
          fi
        } &!
        # pretend we called this directly, instead of the lazy loader
        zle expand-or-complete
      }
      # mark the function as a zle widget
      zle -N lazyload-compinit
      bindkey "^I" lazyload-compinit
    }
```

NateEag on April 23, 2024| | [–]

> Do you have any pointers for the "load on tab" idea? I didn't turn up any good results in DDG and LLMs were just hallucinating.

This is bash, not zsh, but I have this working in my dotfiles by just telling bash where to look for my custom on-demand completions:

https://github.com/NateEag/dotfiles/blob/6862726ad2ecaa3a30e...

I imagine something similar works for zsh.

nikolatt on April 23, 2024| | [–]

I just want to say - thank you! I've been using ZSH since it became the default on macOS and one thing that started annoying me recently is the slow startup time. Your snippet tangibly improved that.

Do you by chance have any good resources on optimising my config further?

bongobingo1 on April 23, 2024| | [–]

Beyond zprof (https://www.bigbinary.com/blog/zsh-profiling) not really I'm afraid. I did the majority of my zsh-prompt hacking 10 years ago and haven't thought about it since. That snippet could be from anywhere.

You could peek at something like zprezto https://github.com/sorin-ionescu/prezto or pure https://github.com/sindresorhus/pure for tips.

Fetching git/hg/... info is always slow, so try and speed that up where you can (as to how to do that, uhh... I know my prompt has a dirty-state check nicked from pure for speed reasons). You can also cache any `asdf init zsh` or similar to a file and do the same "run in background" trick so the next shell will have any changes.

The biggest improvement I can remember was dropping zprezto for my own much smaller config, I really did not need much comparatively. Mostly some git info and "good default" options. I use zgenom for a plugin manager but only have 3 plugins, probably I should just dump it and inline the plugins to avoid getting owned one day.

bongobingo1 on April 24, 2024| | | [–]

You may be interested in this lazy completion loader https://news.ycombinator.com/item?id=40140873

bPspGiJT8Y on April 24, 2024| [–]

> BTW I believe `-C` will disable some cache checking, caching is enabled by default

You're right, my memory has let me down.

> Do you have any pointers for the "load on tab" idea? I didn't turn up any good results in DDG and LLMs were just hallucinating.

The simplest implementation would be something like

```
    bindkey ^I init_completions

    init_completions () {
      # ... init logic here ...

      # rebind tab to complete
      bindkey ^I complete-word
      # actually do complete the initial request
      zle complete-word
    }

```

Edit: I see now you already figured it out, yeah that's exactly what I meant

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### I've used this to speed-up CLI commands which have a slow startup phase. I run t... | Hacker News
**URL:** https://news.ycombinator.com/item?id=40759062

```text
I've used this to speed-up CLI commands which have a slow startup phase. I run t... | Hacker News

perihelions on June 22, 2024 | parent | context | favorite | on: CRIU, a project to implement checkpoint/restore fu...

I've used this to speed-up CLI commands which have a slow startup phase. I run the process up to the point where it finishes initializing things and starts reading input, SIGSTOP there, and resume it later. You can identify that "reading input" library call with strace, and intercept it dynamically with an LD_PRELOAD shim.

I haven't yet figured out how to (neatly) persist this to disk, so I just sort of make a mini server-loop that catches signals and dispatches a fork() for each one, and that's my fast version of the CLI command. Delightfully ugly :)

(The killer app I'm trying to apply this to is LaTeX, so that I can write math notes in Emacs, incrementally, without visible latency. Unfortunately the running LaTeX process is slightly convoluted, and needs a few more tricks to get working in this way. This trick works on the plain TeX command out-of-the-box (it's like a 50x speedup), so I think I'm on the right track...)

karthink on June 22, 2024 [–]

> The killer app I'm trying to apply this to is LaTeX, so that I can write math notes in Emacs, incrementally, without visible latency.

See texpresso [1] for one solution that does something like this with the LaTeX process.

Another, more conservative solution is the upcoming changes to Org mode's LaTeX previews [2] which can preview live as you type, with no Emacs input lag (Demos [3,4]).

[1] https://github.com/let-def/texpresso

[2] https://abode.karthinks.com/org-latex-preview/

[3] http://tinyurl.com/olp-auto-1

[4] https://tinyurl.com/ms2ksthc

perihelions on June 22, 2024 | parent [–]

I wasn't aware of either of those, so thank you very much for those referrals I shall take a close look at :)

(Are you by chance the author of org-latex-preview, or is it a coincidence of usernames?)

karthink on June 23, 2024 | root | parent [–]

I am one of the authors, should have mentioned. It's not part of Org yet, but should be some time this year.
```

---

### Is a 100ms startup time really a big deal for something that is either going to ... | Hacker News
**URL:** https://news.ycombinator.com/item?id=21229054

```text
Is a 100ms startup time really a big deal for something that is either going to ... | Hacker News

Is a 100ms startup time really a big deal for something that is either going to be manually triggered or cronjobbed and expected to take on the order of minutes?

Those sorts of startup times discourage writing command-line tools (e.g. composable text processing things one might join with pipes).

Ruby scripting has occupied the sysadmin space for over a decade yet on my 2013 Macbook Pro the latest Ruby 2.6.5 takes around 250ms to start. That's a mere 1/4 of a second. Sure, Python, Perl and PHP have shorter startup times but surely this is a non-problem?

No, things like sort, grep, uniq, cut, wc, cat, awk, sed, tr, etc etc. You wouldn't want them to take 1/4 second to start up.
```

---

### I know there are real reasons for slow Python startup time, with every new impor... | Hacker News
**URL:** https://news.ycombinator.com/item?id=44370440

```text
I know there are real reasons for slow Python startup time, with every new impor... | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

mikepurvis 8 months ago| parent| context| favorite| on: Fun with uv and PEP 723

I know there are real reasons for slow Python startup time, with every new import having to examine swaths of filesystem paths to resolve itself, but it really is a noticeable breath of fresh air working with tools implemented in Go or Rust that have sub-ms startup.

mr_mitm 8 months ago| [–]

You don't have to import everything just to print the help. I try to avoid top-level imports until after the CLI arguments have been parsed, so the only import until then is `argparse` or `click`. This way, startup appears to be instant even in Python.

Example:

```
    if __name__ == "__main__":
        from myapp.cli import parse_args

        args = parse_args()

        # The program will exit here if `-h` is given

        # Now do the heavy imports

        from myapp.lib import run_app

        run_app(args)
```

mikepurvis 8 months ago| | [–]

Another pattern, though, is that a top level tool uses pkg_resources and entry_points to move its core functionality out to verb plugins— in that case the help is actually the worst case scenario because not only do we have to scan the filesystem looking for what plugins are available, they all have to be imported in order to ask each for its help strings.

An extreme version of this is the colcon build tool for ROS 2 workspaces:

https://github.com/colcon/colcon-core/blob/master/setup.cfg#...

Unsurprisingly, startup time for this is not great.

Spivak 8 months ago| | [–]

Not to derail the Python speed hate train but pyenv is written in bash.

It's a tool for installing different versions of Python, it would be weird for it to assume it already had one available.

lxgr 8 months ago| | [–]

Oh, that might actually explain the slow line printing speed. Thank you, solves a long standing low stakes mystery for me :)

lxgr 8 months ago| | [–]

The Python startup latency thing makes sense, but I really don't understand why it would take `pyenv` a long time to print each line of its "usage" output (the one that appears when invoking it with `--help`) once it's already clearly in the code branch that does only that.

It feels like like it's doing heavy work between each line printed! I don't know any other cli tool doing that either.

heavyset_go 8 months ago| | [–]

There's a launcher wrapper shell script + Python startup time that contributes to pyenv's slow launch times.

theshrike79 8 months ago| [–]

The "slowness" and the utter insanity of trying to make a "works on my computer" Python program work on another computer pushed me to just rewrite all my Python stuff in Go.

About 95% of my Python utilities are now Go binaries cross-compiled to whatever env they're running in. The few remaining ones use (API) libraries that aren't available for Go or aren't mature enough for me to trust them yet.

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### I'm trying and failing to imagine a situation where 30ms startup time would be a... | Hacker News
**URL:** https://news.ycombinator.com/item?id=45597270

```text
I'm trying and failing to imagine a situation where 30ms startup time would be a... | Hacker News

I'm trying and failing to imagine a situation where 30ms startup time would be a problem. Maybe some kind of network service that needs to execute a separate process on every request?

30ms is pretty close to noticeable for anything that responds to user input. 30ms startup + 20-70ms processing would probably bump you into the noticeable latency range.

People play midi keyboards with 30 ms latency.

Yeah I don’t think 30ms is very noticeable, but say you have a cli tool with other 20-70ms to bump you up to 50-100ms your tool will have noticeable latency. Death by a thousand cuts.

30ms is the absolute best case. Throw some spring in there and you're very quickly at 10s. rub some spring-soap and it's near enough to 60s

And imagine if you start adding sleep calls! Those could take minutes to hours, or even days!

New HN submission: How I Made My Sleep Function Accidentally Quadratic.

It's not about how long someone is willing to wait with a timer and judge it on human timescales, it's about what is an appropriate length of time for the task.

30ms for a program to start, print hello world, and terminate on a modern computer is batshit insane, and it's crazy how many programmers have completely lost sight of even the principle of this.

Java is a tool, a very good one.
```

---

### > unlike full-JVM Clojure it has a very fast startup time I can't believe that a... | Hacker News
**URL:** https://news.ycombinator.com/item?id=40446710

```text
> unlike full-JVM Clojure it has a very fast startup time I can't believe that a... | Hacker News

> unlike full-JVM Clojure it has a very fast startup time

I can't believe that after all these years Java still didn't fix their startup time.

The JVM cold-starts, loads a Hello, World program from a compressed JAR, runs it and shuts down in 40ms. But Clojure compiles quite a bit of Clojure code generating hundreds if not thousands of classes and then loads them before starting up the Clojure program. Still, there's ongoing work on the JVM (Project Leyden [1]) to speed up both startup and warmup even of such programs by caching more state.

[1]: E.g. see https://spring.io/blog/2023/10/16/runtime-efficiency-with-sp...

>>The JVM cold-starts, loads a Hello, World program from a compressed JAR, runs it and shuts down in 40ms.

Im yet to reach the X-men level super qualities that can detect, and work in 40 ms chunks. Or at least even notice a 40 ms delays.

I envy the humans who can notice such small chunks of time.

Right, but the problem is that many programs do a lot more work when they start up than Hello, World. The Clojure runtime in particular does quite a lot at startup.

I don't like how this issue is constantly dismissed out of hand. It very obviously is actually a massive glaring issue which severely limits what clojure can reasonably be used for. Nobody would ever accept a 1 second startup time for CLI applications that we use all the time like git, kubectl, npm, docker, etc.

npm, docker, kubectl honestly, you are splitting hairs. I plan to run a process for hours, I think 40 ms delays are something I can live with.

git- I take more time to write the commit message to worry about 40 ms.

I mean sure optimise code to run it fast. But its not something that a human notices.

40ms? Clojure Hello World startup time is like 600ms and up. Yes sometimes you run npm and kubectl for hours but most of my usage is just running individual commands that take less than a second.

You still don't see many scripts or CLI apps in Java though. I was wondering if that would change now that you can run a source file directly, but then wouldn't the startup be slower, because now it's also having to compile.

Why can't you do some JVM equivalent of memcopy/execve the starting state of the program?

Isn't the initialization procedure (or at least the vast majority of it) exactly the same at each run ?

That's pretty much the idea behind Project Leyden's "premain" work. The tricky bit is that the program startup being almost exactly the same each time isn't quite the same as being exactly the same. The JVM already caches some things and the capabilities of that mechanism are being expanded to cover more, including JITted code as well as some program computations done at initialisation.

Back when I wrote Clojure professionally, using GraalVM to generate a native executable of things like clj-kondo basically eliminated the startup latency.

Right, but Native Image comes with its own tradeoffs. Lyeden's "premain" work aims to be somewhere between the situation today and Native Image.

It's a tradeoff. The startup time of Clojure on the JVM is slower than most, but the runtime is faster than most. It also needs a lot of memory to get going. This means it's optimized toward long-running programs like web servers. During development, you use the REPL interactively which makes this a non-issue, but it does take some getting used to at first.

That said, there are alternative runtimes that have different tradeoffs. For example, Babashka is a runtime for Clojure that uses GraalVM instead of the JVM as the foundation. Babashka scripts have about a 10ms startup time on my M1 MacBook Air.

My understanding is that this isn’t really a JVM thing, but I might be wrong.

Your understanding is correct. JVM startup accounts for a small portion of Clojure's startup time.[1] Most of the overhead is in compiling and loading clojure.core. Efforts have been made to remedy this issue[2] (e.g. direct linking, ahead-of-time compilation, ...), but this doesn't remove the fact that clojure.core is huge and virtually any Clojure program will be importing more than just clojure.core, so there is still a lot of var derefs to deal with, then code to compile, then classes to load, etc.

Well, it's still partially the JVM at play. For example, if your application has big classes, and many classes, the JVM will be slow to start. This is what is happening here. Clojure is like a large-ish Java project, it has big classes, and many of them, with static initializers, that need loading at the start, and the JVM does all that slowly.

In some sense it's Clojure's fault for having an implementation that causes slow JVM startup, but it's also the JVM's fault that the way Clojure uses it causes it to take a long time to start.

The various JVM implementations have mechanisms to fix that, like JIT caches and AOT compilation, which Clojure doesn't take advantage of.

So it is indeeed a Clojure issue, not a JVM one.

Can you talk more about these?

AOT compilation with PGO, available for free on GraalVM and OpenJ9.

Also available since around 2000 from comercial vendors, of which, Aicas and PTC are the main survivors.

OpenJ9 also does JIT caching across executions, https://eclipse.dev/openj9/docs/aot/

OpenJDK also does caching but at higher level,

Project Leyden plans to add a similar JIT cache like on OpenJ9, https://openjdk.org/projects/leyden/notes/02-shift-and-const...

Azul and OpenJ9 have cloud JIT servers, that share execution heuristics and dedicate servers for highly optimizing compilers,

Finally, although technically not really Java nor JVM, the Android Runtime (ART), does a mix of high performance interpreter written in Assembly, JIT, AOT compilation, and PGO sharing across devices via Play Store (cloud profiles).

Well, quite a few people already use AOT with PGO from GraalVM to build native executables of Clojure programs. Those start stupidly fast. I never heard of anyone doing so with OpenJ9, how good is the AOT of OpenJ9?

AppCDs in OpenJDK currently has terrible ergonomics. Clojure can't really offer it. Each user must go out of their way to leverage it. So you can't really release an app that automatically leverage it, the user needs to launch it with all the command incantations, etc. And it's so sensitive to class path changes, etc. It kind of sucks to be honest. But some people still use it for prod release, since you can set it up in a docker easily. But the use-case for fast startup are desktop apps, CLIs, scripts, etc. And for all those, AppCDs are super annoying to setup. See: https://ask.clojure.org/index.php/8353/can-we-use-appcds-to-...

Still, AppCDs don't fully solve the startup issue, because all the static initializations stuff takes a considerable amount of time, and that does not get cached by AppCDs.

When you get into REPL-driven development, the JVM startup time (which is often under a second for me anyways) is a total non-issue. You don't continuously restart your program to see changes or run tests. You can refresh all your state instantly without exiting.

But before Babashka, that was indeed a barrier to using Clojure in shell scripts. Now we have it all!

Except in Babashka you can't use Java libraries.. Right?

I feel a good fraction of code will dip into Java libs at least a bit - so you're limited in what libraries you can use

I think the real solution is probably Graal native - though it's not part of the official toolbox/deps.edn

In Unix it is customary to invoke tools from the Bash shell or Bash scripts. That doesn't mix well with a separate REPL.

I see your point here... I was addressing to the feedback loop during development time. Babashka works well for Clojure in a Unix tool pipeline.

It's also possible to compile your JVM Clojure program yourself to a binary with GraalVM for even better performance than Babashka and even faster startup.

Clojure and Common Lisp are the two cases where I’ve never felt the need to work in bash: most projects grow a library of utilities for development that aren’t limited by the stringly-typed nature of bash or zsh

We detached this subthread from https://news.ycombinator.com/item?id=40445197.

I think, in a lot of cases when people still complain about "the slow startup time of the JVM", they're really just talking about how the big JVM GUI apps (like IDEs) struggle to get started on heavily-loaded systems. And this, I think, is mostly just due to these apps eagerly reloading the most recent workspace on startup, and so pre-allocating big chunks of memory on startup to be ready for that — which can ripple out, on systems with low free memory, as other, colder processes all bottlenecking together on the IO of having their own memory written out to swap; and/or to having dirty mmaped pages forcibly-flushed to disk en masse so that the page-cache entries they live in can be purged.

Much more rarely — mostly when talking about writing CLI tools in a JVM language — people actually are complaining about the single second-or-so it takes the JVM to start up. (Usually because they want to run this tool in a loop under xargs(1) or find(1) or something.)

This last second of startup lag is (AFAIK) quite hard to improve, as it's mostly not the JVM itself starting up, but the static methods of JVM classes being called as those classes are loaded — which can do arbitrarily much stuff before any of your own code gets control. (Due to legacy code expecting to read certain per-boot-dynamic info as static fields rather than as the results of static method calls, I believe the JRE runtime is actually required to do quite a lot of that kind of static initialization, to pre-populate all those static fields, just in case something wants to read them.)

---

You'd think that GraalVM could inherently skip most of this, because the Graal compiler does dead-code analysis. "If nothing in your code reads one of those static fields, then nothing needs to write that field, so let's not invoke the static initializer for that field." But that's not true: static initializers are exported and called by the runtime — so they're always "alive" from the compiler's perspective. The Graal compiler isn't doing full-bore data-flow analysis to determine which static members of which classes are ever read from.

I believe GraalVM does try to work around static initializers as much as it can, by pre-evaluating and snapshotting as much of JVM runtime's static initializer code as possible by default, converting it all into const data structures embedded in the class files before the native codegen step gets run on it (see: https://www.graalvm.org/latest/reference-manual/native-image...).

It's not possible to apply this pre-baking to 100% of classes, sadly — some of these data structures need environment data like env-vars or system network config threaded into them on boot.

(I wonder anyone on the Graal project is working on a fully-general static-initializer optimization pass, that does something like concolic execution to bake these initializers out into either fullly-constant data if possible, or if not, then constant "data templates" plus trivial initializer functions that just gather up the few at-boot context fragments, shove them into the "data template" using a low-level hook, and then memcpy the result out onto the heap and call it an object.)

They are working with PGO, and adding also AI based optimization algorithms, both can help.

The problem lies with Clojure implementation, not Java or the JVM.

It's not the JVM.

It's how much code you load.

I mean... That's not an issue in other runtimes, so it's kind of a JVM quirk no?

Those other runtimes also don't do half of the features a JVM usually has to offer, and most people complaining also don't bother to actually learn the Java ecosystem, the existing set of JVM implementations, and the optimizations features made available to them.

No, that's defiantly true in other non-native runtimes.

E.g. any Python project has to deal with this, like Mercurial.

Java projects tend to (insert stereotype) have a lot of code.
```

---

### If you are mindful and optimize your shell config, yea. But common stuff like zs... | Hacker News
**URL:** https://news.ycombinator.com/item?id=39078095

```text
If you are mindful and optimize your shell config, yea. But common stuff like zs... | Hacker News

If you are mindful and optimize your shell config, yea.

But common stuff like zsh with oh-my-zsh is known to be rather slow, as in several hundred millisec to start.

Depending on you, of course, that might be considered fast. I consider it insanely slow.

My shell of preference, "nushell":

> Startup Time: 24ms 448µs 147ns

Ideally it would launch in < 16ms (1 frame at 60hz), but I can live with this ;-)

Why would you need to optimize the config? I'm not talking about running an interactive shell.

You commented on someone mentioning bash being slow to start.

So your parent discussed interactive shell, and I assumed you did, since you didn't state otherwise.

They were quoting the article, which complains that "shells are too slow to start", with examples of running echo in non-interactive shells.

Nobody is talking about the startup time of interactive shells.

on my crappy old i5 dell laptop running ubuntu 22.04 i see ~1.5ms for bash and ~1ms for sh. i dunno where these really bad numbers are coming from tbh.
```

---

### kitty startup time was slow because of a bug in GLFW, fixed a while ago. And you... | Hacker News
**URL:** https://news.ycombinator.com/item?id=25940051

```text
kitty startup time was slow because of a bug in GLFW, fixed a while ago. And you... | Hacker News

kitty startup time was slow because of a bug in GLFW, fixed a while ago. And you can have its startup time be 0 with --single-instance.

Using the latest kitty release 0.19.3 vs. st, both already loaded:

```
  ~ >=> time st ls

 real   0m0.048s
 user   0m0.041s
 sys    0m0.008s
  ~ >=> time kitty ls

 real   0m0.239s
 user   0m0.173s
 sys    0m0.059s

```

If kitty isn't nicely cached it takes over 500ms on my machine. Using your suggested flag it still takes twice as long.

You need to run kitty -1 to start kitty and leave it running. Then all future kitty -1 invocations will open new windows instantaneously.

I use kitty.

"time kitty -1 true" takes about 180ms on my machine. That's more than fast enough for me, but certainly slower than many other terminals.

It's still an order of magnitude slower during startup than other terminals such as xterm, rxvt or even mlterm. On my intel laptop I can often see the gl context flashing before becoming the final background color, which is annoying. Requires also way more ram.

kitty is a great terminal, but it's one example of fast not being also lightweight.

I cant reply to your other post, so: you need to run the other kitty instance also with -1. If you do that, you will get the same numbers I got.

I know, I'm actually using kitty regularly.

time kitty -1 false real 0.098 user 0.080 sys 0.017 maxmem 23 MB faults 0

time xterm false real 0.052 user 0.035 sys 0.000 maxmem 9 MB faults 1

Doesnt look like an order of magnitude to me.

xterm false 0.06s user 0.01s system 81% cpu 8Mb mem 0.090 total

mlterm -e false 0.08s user 0.02s system 84% cpu 13Mb mem 0.125 total

kitty -1 false 0.22s user 0.05s system 93% cpu 78Mb mem 0.290 total

(and yes, there's a kitty instance running already..)
```

---

### How are start-up times? I mostly like kitty but I’ve noticed that it takes a cou... | Hacker News
**URL:** https://news.ycombinator.com/item?id=41225699

```text
How are start-up times? I mostly like kitty but I’ve noticed that it takes a cou... | Hacker News

How are start-up times?

I mostly like kitty but I’ve noticed that it takes a couple seconds to start up when I put my cpu down to 400Mhz. (Which might seem like an odd thing to do, but xterm handles it fine and, hey, why do we need billions of clock cycles to start up a terminal? That’s ridiculous).

Try using `kitty --single-instance`.

Just out of curiosity, what reason do you have to do that? Really curious to hear.

400 is a bit extreme, it is as low as my clock will go. But I often go down to 1200 or 800.

I have an OLED screen and mostly use black background terminals, so I can get some pretty decent battery life out of it, especially at night when I dim the screen.

Dim/red shift/slow CPU is a nice low-distraction night time mode IMO.

Plus it is keeps my palms comfortable even if I accidentally run a computationally intensive code.
```

---

### I quite liked Kitty, and wanted to keep using it. But the slow startup was a dea... | Hacker News
**URL:** https://news.ycombinator.com/item?id=43134849

```text
I quite liked Kitty, and wanted to keep using it. But the slow startup was a dea... | Hacker News

I quite liked Kitty, and wanted to keep using it. But the slow startup was a deal breaker for me. Even with `--single-instance` it was at least 5x that of st for me, which is noticeable for an app I use very frequently. Besides, I'm not a fan of running a single instance of any app, since if (when) it crashes, all my work is gone.

Then I had a look around their issue tracker, and noticed others complained about this too[1]. And the dismissive and defensive response from the author just rubbed me the wrong way.

Strange, it actually endeared him to me. Thanks for the link. I guess some crusty part of me enjoys seeing someone who actually knows what they are talking about not putting up with whiny demanding randos on the internet. I might even give kitty a second chance on windows, to clarify I don't think you are wrong to feel the way you do, it just gave me a chuckle how differently different people parse things.

The only person whining in those threads is the creator sadly. The users are offering an issue they encountered and the author told them off...
```

---

### Fish functions are just gorgeous, and what made me drop Zsh like a hot potato. S... | Hacker News
**URL:** https://news.ycombinator.com/item?id=24633603

```text
Fish functions are just gorgeous, and what made me drop Zsh like a hot potato. S... | Hacker News

Fish functions are just gorgeous, and what made me drop Zsh like a hot potato. Suppose you want to make an automatically loaded (that is, not defined in the shell's rc file) function called foo. Here's how you do it:

- Make a file named ~/.config/fish/functions/foo.fish

- Inside it, define a function named "foo"

That's it. Now when you open a new shell and try to run the command "foo", Fish will look for the file named foo.fish in that directory, load and execute it, then call the foo function from in it.

Now, create an autoloaded function in Zsh or Bash without looking at a man page.

There are a million little niceties like that where I'd assumed that a certain task had to be complicated because every shell I'd used before had made it complicated, but then Fish came up with a nice convention for making it simple. Want to make a function to dynamically set your shell's prompt? Create a function named "fish_prompt" in the file ~/.config/fish/functions/fish_prompt.fish. Ta-da - turns out it doesn't have to be a pain in the neck to do that.

I completely agree about using it as a scripting language, though. It's great for making functions for your interactive shell, but stick with sh or bash (or Python) for writing more sophisticated stuff.

> Now, create an autoloaded function in Zsh or Bash without looking at a man page.

For zsh:

- Make a file named ~/.config/zsh/functions/foo

- Inside it, define the body of the function for foo

- Add ~/.config/zsh/functions/foo to $fpath with "fpath+=~/.config/zsh/functions"

- Declare foo with "autoload -Uz foo"

> Want to make a function to dynamically set your shell's prompt? Create a function named "fish_prompt" in the file ~/.config/fish/functions/fish_prompt.fish. Ta-da - turns out it doesn't have to be a pain in the neck to do that.

To do the same in zsh:

- define a function (can be autoloaded or not) named prompt_foo_setup to change your prompt

- add the following to your zshrc: "autoload -Uz promptinit; promptinit"

Now you can easily change to your custom "foo" prompt by running "prompt foo".

There are many valid points which make zsh (or bash) hard to use out of the box, but neither of the points you've raised are one of them. One can easily do both without "looking at the man page."

That's what I'm talking about. I'm super comfortable reading the man pages for things, but if a tool wants to take over all the boilerplate and do things for me, awesome! Sure, I can add a function by editing rc files. That doesn't scare me one bit. But... why? There's a lot to be said for convention over configuration.

For context, for a while I was the FreeBSD port maintainer for shells/bash-completion. I'm (too) familiar with the plumbing of various shells. I can do all the manual work myself, but there are lots of things I'd rather be doing instead.

> One can easily do both without "looking at the man page."

How do you know which flags to autoload to use without reading the docs? How did you know to call autoload?

Oh please. The exact same thing can be said for fish. How did the parent commenter know to create a file named ~/.config/fish/functions/foo.fish? How did the parent commenter know to define a function inside that file?

The point is, it's trivial to create an autoloaded function in both fish and zsh. You don't have to look at the man page each time, which is what was being implied in the comment I was responding to.

But to answer your question, you never need to call autoload with flags other than "-Uz" 99.99% of the time. So the idea that you have to consult the manual each time to figure out the flags is plainly not true. As for the fact that you have to call autoload to bring autoloaded functions into scope, what else did you expect? Fish's behavior of bringing undeclared functions into scope isn't exactly intuitive either.

Or even more simplified:

```
    funced foo
    funcsave foo

```

funced will either allow you to edit it inline, with a clever multiline system, or through your $EDITOR.

funcsave will record the file to the place you want once you're happy with the changes.

Which means you can funced as many times as you want on both new and old alike until you're happy with the function.

Or even easier:

```
    funced foo

```

Then edit your function in the editor, save and close it, and then:

```
    funcsave foo

```

to make sure it's there in the future sessions. Without that second step you can create one-time helper functions for the active session.

```
  for fname in $(ls ~/.config/zsh/functions); do source $fname; done

```

:)

That’s the exact opposite. That’s eagerly loading all defined functions. autoloading means the function isn’t loaded until it’s used.

When are you going to run that?

GP is talking about JIT loaded functions: 'that is, not defined in your shell's rc file'.

for fname in ~/.config/zsh/functions/*; do source $fname; done

will prevent issues with special chars and spaces in filenames
```

---

### Setting a specific path as an “autoload” path to load shell functions is in bash... | Hacker News
**URL:** https://news.ycombinator.com/item?id=28935769

```text
Setting a specific path as an “autoload” path to load shell functions is in bash... | Hacker News

krinchan on Oct 20, 2021 | parent | context | favorite | on: s/bash/zsh/g

Setting a specific path as an “autoload” path to load shell functions is in bash and zsh too?

laumars on Oct 20, 2021 [–]

Yeah, but there aren’t magic function paths that you need to do basic things like setting the prompt.

Don’t get me wrong, I think the PS1 variable sucks. But I’m not convinced Fish’s solution is much better.

krinchan on Oct 21, 2021 | parent [–]

Okay so I think I understand your objection a bit more. So fish only wants you to define a function called fish_prompt in order to customize the prompt. That function can be defined however you want. It can be in fish’s equivalent of .bashrc (~/.config/fish/config.fish). Putting it in ~/.config/fish/functions/fish_prompt.fish is just leveraging more tooling around shell function autoloading and sane defaults.

You can achieve PS1-like functionality “simply” by placing this bit of code somewhere in your startup:

```
  function fish_prompt
      set -l prompt_symbol '$'
      fish_is_root_user; and set prompt_symbol '#'

      echo -s $hostname (set_color blue) (prompt_pwd) \
      (set_color yellow) $prompt_symbol (set_color normal)
  end

```

 It’s very verbose but it runs as fast as both bash’s PS1 and zsh’s PROMPT and is much easier for someone new to fussing with prompts to comprehend.

Even as someone who doesn’t use fish day to day, I think fish’s prompt customization is much more approachable. If I had a powerline prompt I wanted to tweak, I’d know to start with `functions fish_prompt` to print out the current contents of the function and have the complete code to how the prompt is built. zsh requires a lot more reading and understanding of the prompt system before you can dig into how exactly it all works. IIRC, most dynamic bash prompts have similar issues. PS1 is just interpolated globals and color codes, creating a disconnect between the prompt variable and the shell functions that update it.
```

---

### Bringing down my ZSH load times from ~3.1s to ~230ms | Hacker News
**URL:** https://news.ycombinator.com/item?id=48573813

```text
Bringing down my ZSH load times from ~3.1s to ~230ms | Hacker News

Bringing down my ZSH load times from ~3.1s to ~230ms (iam.mt)

44 points by speckx 61 days ago | hide | past | favorite | 26 comments

kstrauser 61 days ago | next [–]

I have a complex fish shell configuration with ~100 autoloaded functions and about 180 lines across config.fish and a dozen conf.d/ files.

On my system, hyperfine says fish loads in about 85ms:

```
  Benchmark 1: fish -il -c exit
    Time (mean ± σ):      85.0 ms ±   3.3 ms    [User: 50.1 ms, System: 31.4 ms]
    Range (min … max):    82.9 ms … 101.1 ms    28 runs

```

 And that's without giving up a single thing in the name of quickness. Stick with zsh if you want, but understand that there are tradeoffs. And for the fish end of those tradeoffs: 1) most command lines work identically between fish, zsh, and bash; 2) where they don't, the fish version is nearly always more pleasant and obviously correct for interactive use; and 3) you don't have to uninstall bash, ya know — you can still `curl foo | sh` to run some random script off the net if you feel the desire. Your existing stuff doesn't stop working.

adrian_b 61 days ago | parent | next [–]

On my 6-year old PC, an interactive zsh starts more than 4 times faster, but this is a rather minor detail.

Which are in your opinion the advantages of fish over zsh?

The fish tutorial from its Web site highlights some very important advantages of fish over bash/ksh/sh, but all of them are taken from zsh, which had them long before the creation of fish (e.g. features that eliminate the need for the excessive quotation that is necessary in bash/ksh/sh).

Fish has various syntactic differences in comparison with zsh, in some places fish is more concise, but in others it is more verbose, and it is more verbose in things that are more frequently used (e.g. "set" vs. "=", "and" vs. "&&" etc.), while being more concise in things that are more rarely used.

Therefore, from the fish tutorial I see why it is preferable to bash/ksh/sh, but I see no reason to prefer it to zsh.

kstrauser 61 days ago | root | parent | next [–]

This is my go-to example:

Say you want to make an autoloaded function in zsh. Go ahead and look that up. Unless you're one of the zsh maintainers, you probably don't have that syntax memorized. I don't mean that personally. The whole time I used zsh, I certainly didn't remember it and had to look it up each time.

In fish, you define a function named "foo" in a file in a specific directory: ~/.config/fish/functions/foo.fish. That's the entire process. When you type "foo" at the command line, and fish can't find that command anywhere, it'll look in that directory for foo.fish, and if it finds it, it'll load that file and execute the "foo" function defined inside it.

Now, say you want to customize your zsh prompt and have it show you the output of a couple of commands, maybe with some colors. It's a fun exercise to try to get something working purely from memory, but that's a test I never managed to pass.

Want to do it in fish? Follow that pattern above to define an autoloaded function called "fish_prompt". Put it in ~/.config/fish/functions/fish_prompt.fish. It's just a normal function where you can use "echo" and "git" and any other command on your system to write the components of your prompt to stdout. That's it. You're done. There's no step 2. Any other time I want to draw something on the screen, I'd use a series of shell commands to write it out to the screen, so why shouldn't it work exactly the same way for my shell prompt? Well, with fish, it does.

That expirement ruined bash and zsh for me. I don't spend a lot of time continually customizing my shell prompt, but the once every couple of years I want to, it's a huge relief to know I just have to edit that function to write out my new idea and that's the end of it. There's just so much less magic to learn and remember with fish that I don't want to go back.

And to be clear, I know my way around several other shells. I love fish because I've used the others enough to become very competent with them, not because I don't know the others or they're too hard for me or anything like that. By programming language analogy, I'm capable of writing decently sized programs in a few flavors of assembler. But man, life's too short to use it for everything, unless that's just the kind of hair shirt you're into wearing.

adrian_b 61 days ago | root | parent | next [–]

Thanks.

I use a rather complicated zsh prompt, complicated enough so that I could never convince bash to execute an equivalent prompt correctly, despite the fact that the features used by the prompt are supposed to be supported in bash too.

(The prompt syntax is quite different in zsh and in bash. This is the zsh syntax of my prompt:

```
  PS1=%F{cyan}"[%T %n@%m:%~]"$'\n'%#%f
```

As you say, to be able to write the prompt I had to study carefully the zsh manual.

However, I consider this a minor disadvantage, because I have written the prompt many years ago, when I have switched from bash to zsh, and I have never had any reason to change it.

I agree that for rarely used features it is more likely to be necessary to search the manual for zsh than for fish, but for me this happens seldom enough to not consider it a decisive disadvantage.

kstrauser 61 days ago | root | parent | next [–]

I do get that, and thought that way too at first. In my case, I found that it being so trivially easy to do these 2 things made them things I did more often. Go ahead and make a thousand convenience scripts and aliases for whatever mischief you want to get up to. There’s no measurable effect on startup time between have 1 autoload function and 1,000. Because it’s free, and so dead simple to do, I never avoid it anymore. There’s no worrying of my startup script’s getting too long and slowing things down, so there’s no downside to doing the things that make my life easier.

For me, it unlocked a completely different mindset. Fish isn’t for everyone, any more than chocolate or steak are, and that’s cool. I’m glad we have options.

thallavajhula 61 days ago | parent | prev | next [–]

That's a ridiculously low number. Wow! I don't think my personal mac has such speed either. I should definitely try this out.

ricardobeat 61 days ago | prev | next [–]

Having gone through the same experience, I suggest dropping fnm as well; I don’t recall what exactly causes it, but it will eventually slow down too.

I’ve been using mise [1] to manage node versions since with zero issues.

[1] https://mise.jdx.dev

thallavajhula 61 days ago | parent | next [–]

I haven't had any issues with `fnm` so far. It's been fast and I like how it prompts you to install a missing node version as soon as you jump into a directory with a `.nvmrc` file.

c-hendricks 61 days ago | root | parent | next [–]

Mise does similar, but for a while suite of tools instead of just nodejs.

thallavajhula 61 days ago | root | parent | next [–]

Will check it out, thanks!

AprilArcus 61 days ago | prev | next [–]

How did I know it was going to be `nvm` before I clicked?

supriyo-biswas 61 days ago | parent | next [–]

All the package managers that provide shell wrappers kinda tend to be bad at this, unless they use their own command to wrap over project specifications, like uv.

These days, I've been personally relying more on direnv to automatically activate certain shell configurations, and then nix to manage binary dependencies like node or go or php.

jdxcode 61 days ago | root | parent | next [–]

mise isn't, and has the advantage that you don't need to build your own lightsaber with direnv and nix.

ricardobeat 61 days ago | root | parent | prev | next [–]

In my experience direnv is also a source of slowness. How fast is it for you?

drdexebtjl 61 days ago | root | parent | next [–]

My understanding is that nix-direnv caches the environment, so after you first evaluate it, it’s pretty much instant.

I haven’t timed it, but it’s not perceptible imo.

tecoholic 61 days ago | prev | next [–]

Use mise and you will be in the micro-seconds region.

https://arunmozhi.in/2024/09/06/replacing-pyenv-nvm-direnv-w...

Alifatisk 61 days ago | parent | next [–]

Mise looks like ”asdf”

https://asdf-vm.com

vivzkestrel 61 days ago | prev | next [–]

- none of your blog links work https://iam.mt/blog-changes/

- also you should put a list of all your article. (titles only) on some page called /archive or something

- i really dont want to scroll 5000 pages to see the last 20 articles you wrote

- just a suggestion from a ui / ux perspective

thallavajhula 61 days ago | parent | next [–]

will add a page, thanks for the suggestion.

adrian_b 61 days ago | prev | next [–]

Even the final starting time for zsh from TFA is quite bad.

On a 6-year old desktop PC with a Ryzen CPU, an interactive zsh starts in 20 ms and a login zsh starts in 60 ms.

The configuration file for the interactive zsh, i.e. "~/.zshrc", has 75 lines and it configures completions (in the default manner added to ~/.zshrc by compinstall), binds some keys, sets umask and some shell options and defines a bunch of environment variables (including the prompt) and of command aliases.

I do not see what else would be needed, which could increase the starting time.

My login zsh takes 40 ms longer because I do not use a GUI login, but the classic CLI login, so the login zsh checks if a GUI desktop session is running and if not it starts the session (obviously, the 60 ms login zsh starting time is for when the GUI session is already running).

lanycrost 61 days ago | prev | next [–]

Because of the performance and stability issues I moved to fish for 1 year and I like it even more, it's syntax, functions it's tab completions, for some reason with zsh I always had an issues, my bad, but fish work perfectly out of the box.

jauntywundrkind 61 days ago | prev | next [–]

My mini-story: I'd switched to zimfw which does a ton of caching, precompiling. It benches very well versus other zsh frameworks. But something was still taking almost a second for me, every time. https://github.com/zimfw/zimfw

zprof helped me and the LLM profile and we found it was one plugin, which wasn't really intended specifically for zim. Fixed that! https://github.com/lipov3cz3k/zsh-uv/issues/2

Man it feels so good having shells just open so lightning fast.

jasonpeacock 61 days ago | prev | next [–]

Huh, I just ran the same timing command for my fish shell (with starship prompt) and got 168ms.

What all is happening in the Zsh profile?

basetensucks 61 days ago | prev | next [–]

Adopting https://github.com/marlonrichert/zsh-snap was probably the best decision I've made around zsh in the last five years.

throwwwll 61 days ago | prev [–]

Nobody who uses nix has ever had such problems.
```

---

### I switched to fish a few years back after a couple decades of using bash. It too... | Hacker News
**URL:** https://news.ycombinator.com/item?id=28932048

```text
I switched to fish a few years back after a couple decades of using bash. It too... | Hacker News

I switched to fish a few years back after a couple decades of using bash. It took about 10 minutes to make that permanent everywhere – because so much is built-in and the defaults are good, there was no need to spend time on more than the package install plus chsh.

For scripting, I’d already set a personal policy that anything complicated use Python. For me there’s a fairly big difference between interactive shell sessions and scripts which solidly shifts the balance to a full language with a rich standard library and robust error handling. My scripts were edited using shfmt and shellcheck interactively anyway, so switching to Python wasn’t an increase in terms of tool support and the richer language means that I’m writing less code to get more functionality and especially error handling.

Same here. It's just so ergonomic. For instance, here's how to make a fancy prompt in fish:

- Write a function called "fish_prompt" with "echo", "set_color", and whatever else you want.

- Put it in a file in fish's "functions" directory called "fish_prompt.fish"

That's it. Done. Every time fish needs to display a prompt, it does so by calling the "fish_prompt" function. Where does fish find the definition of a function called "foo"? In a file called "foo.fish".

Oh, do you want one of those very cool right-side-of-the-window prompts showing the date, maybe? Write a function called "fish_right_prompt.fish". There, you're finished.

There are a million little niceties like this that seem so obvious in retrospect. Fish is what happens when someone completely rethinks a shell from the perspective of how things should be done today after we have a few decades of experimentation under our belt.

Finally, a command line shell for the 90s

I’m glad that works for you but that sounds like a horrible solution to me. Maybe better than Bash but magic named files are probably my least favourite feature in scripting languages.

Don't think of it as magic, but as convention. Where do you put your function definitions? In the folder named "functions". There are only a handful of such things to learn.

> Where do you put your function definitions?

Inside ‘function’ blocks, like the language syntax defines for any other type of function. I can then throw those functions into any file I chose.

Having special functions inside special files just creates annoying special cases I need to look up.

In fish, you put the functions inside function blocks. There's nothing at all magical about that. However, if you write "function foo" inside a file named "foo.fish", then type the command "foo" at the shell prompt, then fish will look for a file named "foo.fish" and then execute the function "foo" defined inside it. That's its autoload mechanism.

That's the only remotely magical thing added here: by convention, an autoload function named "foo" is defined in ~/.config/fish/functions/foo.fish.

Your .bashrc, .zshrc, .profile, etc. files are also special. All that's going on is that there is folder where you can leave functions to be included in the main namespace, I don't see the big difference.

The difference as I understand it is your Fish equivalent of a $PS1 (and other Fish shell behaviours) have to be defined via that path. If I understand it correctly, it sounds a lot like git hooks but at a global scale rather than per repo.

Now I’ve got nothing against git hooks nor Fish per se, I just don’t see this particular model for defining behaviour to be convenient (eg what if you want to quickly change the prompt of a session without affecting other sessions?)

There might be more detail I’m missing and if that’s the case I apologise. But from what I’ve read thus far I’m not sold. It might appeal to others and good for them.

How would you normally do it? Because you can still put redefinitions of all the standard functions into a single file and load them with `.` as you would with other shells.

There's also this package, which the author admits only allows "slight" customization, to implement sessions: https://github.com/farzadghanei/fishion

Well I’m not suggesting the following is a better alt shell, but in murex you have something that’s a little bit akin to a Windows Registry in that all of the shell settings are navigable through a builtin called ‘config’

You can set prompt functions with that; strings, ints and Booleans too. And ‘config’ comes with descriptions for each configurable thing, choices of options in many cases, and an easy way to default back to shell defaults too. So it’s dead easy to play around configuring whatever you want (you never need to leave the shell to look up an option).

The shell has its own problems though but it’s an interesting alternative take for grouping shell config.

>The difference as I understand it is your Fish equivalent of a $PS1 (and other Fish shell behaviours) have to be defined via that path.

They don't. You have to define the function somehow, but fish doesn't care about how that happens. It's just that if it's not defined yet it'll try to load it from the file.

If you want, you can just do it all in config.fish, like you'd do it all in .bashrc for bash.

>what if you want to quickly change the prompt of a session without affecting other sessions?

Then you can redefine the function, just like you could switch the value of $PS1.

Ok. That sounds a lot more sane then. Thank you for the clarification.

You can literally still do it the way you want, there's just a convention that `fish` uses to autoload so you don't have to if you don't want to.

It's as simple and seductive as Ruby on Rails was 20 years ago.

I was going to mount a defense of fish about how it doesn't provide the same mechanisms or provide the same incentives that had people contorting Ruby into the most convoluted forms on their way to spit out HTML or JSON from an HTTP request, but then I found that the thing has a `fish_command_not_found` that you can overload as in Ruby.

So yeah you could make crazy stuff like Rail's routing and rendering DSLs that interpreted method names as programs.

Bash and zsh have basically the same thing.

It's meant to give you a nice error message like

"foo is missing. You can install it with 'apt install foo123'"

See:

- https://zsh.sourceforge.io/Doc/Release/Command-Execution.htm... for zsh

- https://www.gnu.org/software/bash/manual/bash.html#Command-S... for bash

You could make it run arbitrary things, but then you're quite clearly misusing it and e.g. there's no way to make it return a different status, fish will still view the command as failed.

Setting a specific path as an “autoload” path to load shell functions is in bash and zsh too?

Yeah, but there aren’t magic function paths that you need to do basic things like setting the prompt.

Don’t get me wrong, I think the PS1 variable sucks. But I’m not convinced Fish’s solution is much better.

Okay so I think I understand your objection a bit more. So fish only wants you to define a function called fish_prompt in order to customize the prompt. That function can be defined however you want. It can be in fish’s equivalent of .bashrc (~/.config/fish/config.fish). Putting it in ~/.config/fish/functions/fish_prompt.fish is just leveraging more tooling around shell function autoloading and sane defaults.

You can achieve PS1-like functionality “simply” by placing this bit of code somewhere in your startup:

```
  function fish_prompt
      set -l prompt_symbol '$'
      fish_is_root_user; and set prompt_symbol '#'

      echo -s $hostname (set_color blue) (prompt_pwd) \
      (set_color yellow) $prompt_symbol (set_color normal)
  end

```

It’s very verbose but it runs as fast as both bash’s PS1 and zsh’s PROMPT and is much easier for someone new to fussing with prompts to comprehend.

Even as someone who doesn’t use fish day to day, I think fish’s prompt customization is much more approachable. If I had a powerline prompt I wanted to tweak, I’d know to start with `functions fish_prompt` to print out the current contents of the function and have the complete code to how the prompt is built. zsh requires a lot more reading and understanding of the prompt system before you can dig into how exactly it all works. IIRC, most dynamic bash prompts have similar issues. PS1 is just interpolated globals and color codes, creating a disconnect between the prompt variable and the shell functions that update it.

Fish doesn't work with a light theme. (Dark text on white background.) Also the keybindings in fish are extremely unergonomic.

Honestly I just want a bash that saves every command entered, ever, and never deletes history. (I think I can spare the 100 kilobytes of disk space to hold command history forever.)

And fish doesn't get this right either, even though it's a complete no-brainer. Sigh.

So no, I'm not a fan of fish.

`fish` is amazing. I used to have a big old dotfiles repo, but nowadays I add starship[0] to my env and I'm pretty much good to go.

On the non-interactive scripting front, I've found fish to be a very competent language for it, but you're right, the error handling (among other things) are lacking compared to "real" languages

I have to say, I use fish and I customize my prompt... is starship really necessary? I recognize starship is cross-shell, but if I standardize on installing fish on my machines, I'm not sure I need that feature.

Is there a "killer app" for starship that you can't get from writing out your prompt in a fish shell script?

It's a 3-line prompt with a timestamp on the first line, my username@host + pwd on the 2nd line, and the actual prompt with the cursor on the 3rd line. I'm now considering swapping the timestamp to the right side after that possibility was mentioned in other comments in this thread.

I’ve been using fish for years and I love it. I have a simple prompt and a few functions that I share between all of the environments I have.

I've had this experience as well. My zsh config was a monster. fish was extremely easy -- starship and ready to go.

I used fish for around a year and a half and wound up switching back to zsh. fish's startup time is way too long for my tastes, and the devs seem completely uninterested in providing a "don't load plugins" flag. I open up new tmux panes/windows/etc all the time, so fish's slowness here is really noticeable. It also negatively affects using things like `tmux popup`, which spawns a shell. Things like this that take no noticeable time under zsh are sluggish under fish.

Interesting — I picked fish because it was so much faster than zsh but I also run it pretty lean without much in the way of plugins.

I switched to fish for about six months, and recently went back to zsh when I realised that the three things I really liked about it (abbreviations, syntax highlighting and autosuggestions) were all doable in zsh with extensions [0]. (It feels pretty slow, even slower than say OMZ, but that's not such a big deal for me.)

I switched to Fish a couple years ago, and I love it too — the only thing I ever find myself missing from bash is `!!`. The (new) Alt+S keybind to prepend `sudo` to a command covers many of these use cases, but not all of them. For example, sometimes I want to re-run the last two commands; in Bash I could do ` && !!` but there doesn’t seem to be a good way to do this in Fish without having to re-type one of the commands.

Alt+Up is great for recalling individual arguments, but am I missing something or is there no way to recall a whole previous line in-place, without overwriting what’s currently on the command line?

Up-up-Ctrl+K to kill the line; down to go down one in the history; end to go to end of line; `; and` or ` &&` to join the commands; ctrl+Y to yank the line from the killring. [0]

Seems to work in bash too, fwiw.

The first thing in install with oh-my-fish is bang-bang, which fixes this issue for me.

I tried out zsh and just could not get used to how different tab completion was vs bash, so went back to bash quickly. Is tab completion on fish more similar to bash than zsh is?

I use zsh because of its tab completion lol

Totally. And there’s nothing better than fzf-tab

I'll try it out!

Totally agree, it’s very off putting to use zsh auto complete after years of using bash.

Try it for yourself: https://rootnroll.com/d/fish-shell/

Ah cool thanks!

No, fish actually has super fancy autocompletion with suggestions, which is even more complicated and visually messy than the zsh defaults. Furthermore, none of it can be disabled in fish. (This is why I don't use fish, fwiw.)

On the other hand, you can disable all these advanced features in zsh and get something a bit closer to a bash readline shell, with a few extra features. That's what I use.

I didn't find it too much of a switch — it works well and things like Option-> to complete it word by word are really handy with repetitive tasks like using the AWS CLI.

I liked fish a lot but various tooling at work just expected you to be working in something sh-like. I handled sourcing files of env vars with some utility functions but I still found myself having to drop into bash/zsh pretty often.

I feel torn because I really can empathize with making a clean break. But it also precludes a lot of people from making the shell a daily driver when your co-workers are shoving shell scripts your supposed to source into your env into github, lol.

Does fish still not have reverse search? I have a hard time taking a shell seriously if you can't perform an operation at least as good as this. Even Powershell supports reverse search!

I use fzf for reverse search and it works in fish with ctrl+r binding.

I'm guessing someone probably has a plugin for it or people just get used to using autosuggest

What specifically are you looking for? It has history search but it sounds like you’re looking for something specific?

In bash, I can type ctrl+r then type a few characters, and the last command that contains that string will get pulled up and I can hit [enter] to run it.

Not sure if fish has this or not, but I use reverse search in bash exhaustively.

I used to use Control-R a lot and now use the fish equivalent:

I find it to be more polished and especially like the way it works with fragments (e.g. if you start typing "git log" and hit Option/Alt-ꜛ it will find commands prefixed with that whereas bash Control-R requires you to hit Control-R first and then type that, which isn't as handy when you realize you want to search halfway through).

In fish: Just enter the text you want to look for into the commandline and press [up].

There's no need to enter a separate mode via ctrl-r.

That separate mode is incremental search and it's a big advantage. It lets you keep extending the search string until it matches the command you're looking for.

fish is fantastic. abbreviations are very nice, the fish_config gui is helpful if you actually need to configure something, and there's just a lot of utility things like fish_add_path. It's just very pleasant to use.
```

---

### I had to abandon the last time I tried fish because it’s not compatible with my ... | Hacker News
**URL:** https://news.ycombinator.com/item?id=37273056

```text
I had to abandon the last time I tried fish because it’s not compatible with my ... | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

pacifika on Aug 26, 2023| parent| context| favorite| on: Fish – A friendly interactive shell

I had to abandon the last time I tried fish because it’s not compatible with my export PATH declarations from tooling in bash/zsh, any tips?

bin_bash on Aug 26, 2023| [–]

OK so if you're new to fish you should understand universal variables since it's a concept that bash/zsh does not have and it's actually pretty great.

When people first try out fish they want to add their global env vars and PATH configuration to ~/.config/fish/config.fish. You can absolutely do this similar to how you do it in ~/.bashrc. However, it's not idiomatic and once you get used to universal variables, you'll see that it's a lot of yak shaving you really just don't need editing config.fish.

Instead, if you want to permanently set an env var across the current session and all new sessions, run: `set -Ux MY_ENV_VAR 1` (set a universal variable, and export it to subprocesses)

That will put it into a machine-readable file ~/.config/fish/fish_variables. You can open it if you want but this way you don't need to source your rc files, open a new shell, or even open your editor.

For PATH, just run: `fish_add_path ~/my-new-bin`. It uses universal variables by default.

For some reason I avoided universal variables as much as possible for years using fish and now I think that was really silly.

artemisart on Aug 26, 2023| | [–]

Just rewrite them once with fish_add_path? https://fishshell.com/docs/current/tutorial.html#path Or maybe use https://github.com/edc/bass

Flimm on Aug 26, 2023| | [–]

I think later versions of Fish do support export statements. This line of code works with Fish, as well as Bash and Zsh:

```
  export PATH="$PATH:$HOME/foobar/"
```

PufPufPuf on Aug 26, 2023| [–]

You can source bash files (like .bashrc) using the plugin "bass". You can also launch fish using a bash file, just export the variables and run fish as the last command.

I personally just put what path modifications I need in .profile and have fish as my login shell.

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### Why does zsh start so slowly? | Hacker News
**URL:** https://news.ycombinator.com/item?id=33580350

```text
Why does zsh start so slowly? | Hacker News

Why does zsh start so slowly? (pickard.cc)

149 points by todsacerdoti on Nov 13, 2022 | hide | past | favorite | 74 comments

rphln on Nov 13, 2022 | next [–]

I recently had the same problem with Conda's and Pandoc's initializations in Bash.

At first I did the same as the author and just dumped the output from `pandoc --bash-completion` et al. into a file, but then I'd have to deal with cache invalidation on every machine that I use. Doing it manually isn't that bad, but remembering to update the file in a bunch of machines is a bit too much ugly for me.

After a surprisingly short Google session, I ended up settling with lazy initialization [1]. Unlike the post I found, I did it all manually, though. Now I just have this tucked at the end of my `.bashrc`:

```
    function conda {
        unset -f conda

        # shellcheck disable=SC1090
        source <(conda shell.bash hook)
        conda "${@}"
    }

    function _pandoc {
        unset -f _pandoc

        # shellcheck disable=SC1090
        source <(pandoc --bash-completion)
        _pandoc "${@}"
    }

    complete -F _pandoc pandoc

```

 [1]: https://dev.to/zanehannanau/bash-lazy-completion-evaluation-...

paulirish on Nov 13, 2022 | parent | next [–]

I've also spent time profiling shell startup and found conda's init wasn't fast. (And that's consistent in fish shell, tol) Your found solution is elegant; I'll adopt it. nvm and rvm both have initializations have a decent perf hit, too.

dcminter on Nov 13, 2022 | prev | next [–]

Not really related, but this reminds me of an issue I once saw where starting vi on one of our servers took something over a minute. Everywhere else it was imperceptibly fast. It eventually turned out that in the distant past someone had accidentally piped a large file into vi, and so every time it started up it was loading up a command history that included this stupidly big file to absolutely no purpose, annoying everyone but not quite enough that anyone else had tracked down the cause.

mort96 on Nov 13, 2022 | parent | next [–]

Interesting, that'd surely become an issue over time with normal usage as well if it never deletes old entries?

dcminter on Nov 13, 2022 | root | parent | next [–]

Seems the default limit is 20 commands - perhaps someone had overridden it to be much higher. It was about a decade ago though so I may be misremembering something about the issue.

decasia on Nov 13, 2022 | prev | next [–]

Bonus points if zsh measured startup time by default and issued periodic warnings about slow startup dependencies. I wouldn't mind seeing the occasional message to STDERR telling me that `kubectl xyz` is actually adding 250ms to shell startup.

KerrAvon on Nov 13, 2022 | parent | next [–]

This sounds like a great thing to put in the zsh issue tracker.

ngshiheng on Nov 13, 2022 | prev | next [–]

Interesting. In my case, according to `zprof`, 80% of my startup time came from nvm_auto from nvm (node version manager)

it_citizen on Nov 13, 2022 | parent | next [–]

```
  # This lazy loads nvm
  nvm() {
    unset -f nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use # This loads nvm
    nvm $@
  }

```

 Now, nvm only loads when it is explicitly called instead of loading in every shell. In my case, it made a very visible speed difference.

eyelidlessness on Nov 13, 2022 | parent | prev | next [–]

Yeah, nvm is notoriously slow. Volta[1] is much faster.

1: https://volta.sh/

chrisweekly on Nov 13, 2022 | parent | prev | next [–]

I switched from nvm to fnm for this (and other) reasons a couple years ago. Huge improvement on all fronts.

mananaysiempre on Nov 13, 2022 | prev | next [–]

Answer: Because it is sourcing the output of `kubectl completion zsh`, which takes 130ms to execute. (The article says something about zsh “caching” a static sourced file; does it actually do something like that? It still has to run the shell code, right?)

Question: How the hell do you take 130ms to print out the commands to set up shell completion? Is there something meaningful happening in that time, or is this simply the cost for the kernel to load a 43 MB do-everything kubectl binary? (43 MB is a lot, admittedly, but 130ms when most of that code stays untouched still sounds high to me.)

oefrha on Nov 13, 2022 | parent | next [–]

> The article says something about zsh “caching” a static sourced file; does it actually do something like that? It still has to run the shell code, right?

No it does not, the article is wrong or phrased incorrectly.

Zsh completion functions, when properly configured, are autoloaded. The function is only read from disk when called. Say with _kubectl, if you do it correctly with a static _kubectl instead of following the stupid advice of `source <(kubectl completion zsh)`, on shell startup your _kubectl should be uninitialized:

```
  $ which _kubectl
  _kubectl () {
   # undefined
   builtin autoload -XUz
  }

```

 After you actually try to complete kubectl once, run that again and this time you can see the actual function body.

```
  $ which _kubectl
  _kubectl () {
   local shellCompDirectiveError=1
   # ...
  }

```

 That function is read from disk on use, not cached.

What zsh does cache, with compinit[1], is association of commands with completion functions. compinit reads the #compdef line of functions on $fpath (e.g. `#compdef _kubectl kubectl`), and generates a ~/.zcompdump (or some other path, mine is ~/.local/share/zsh/compdump for instance), which is basically a list of command and completion function pairs, plus a huge autoload invocation registering all the completion functions. This way zsh knows which function to load when a command needs completion.

[1] https://zsh.sourceforge.io/Doc/Release/Completion-System.htm...

vbezhenar on Nov 13, 2022 | parent | prev | next [–]

Kernel does not load 43 MB. It maps file to memory and then executes it from start address. During execution, kernel paging mechanism reads parts of the file into memory as CPU touches it. So ideally this print algorithm should take few kilobytes of those 43 MB and 2-3 pages loaded from the disk. With SSD it should be significantly faster than 130 ms.

What exactly happens with kubectl is hard to answer and need someone to profile it if that's true. May be it checks for updates or something like that.

PetitSasquatch on Nov 13, 2022 | parent | prev | next [–]

I have experienced even longer with npm / Node.js autocompletion.

The whole experience caused me to try different shells, I ended up on ksh for simplicity and comparative leanness, works well for my needs.

ilyt on Nov 13, 2022 | root | parent | next [–]

But zsh is not slow, bloat you add to it is...

PetitSasquatch on Nov 13, 2022 | root | parent | next [–]

I agree. I never found zsh inherently slow, but the reason I initially used it was to play with all the additional 'bloat' its ecosystem offered, so to speak.

It was that experience which led me to look try other shells, in the end I found ksh's simpler feature set and manpage more to my liking.

marcthe12 on Nov 13, 2022 | root | parent | prev | next [–]

Which ksh flavour? Also any good tutorial?

ratsmack on Nov 13, 2022 | root | parent | next [–]

I have used the original ksh[1] for years, because it seem to have more features for complex shell scripts. It also supports real numbers for people that need math functions other than integer.

[1] https://en.wikipedia.org/wiki/KornShell

PetitSasquatch on Nov 13, 2022 | root | parent | prev | next [–]

The ksh that ships with OpenBSD, it's available under Linux as loksh. I've never needed a tutorial as such, because found its man page to be well written and comprehensive. However, I can recommend the old book The Unix Programming Environment by Kernighan and Pike, it also is well written and helped me quite a bit. Just understanding one smaller tool (ksh) better has helped me do more with it and use fewer addons extensions, which personally make me happy; works for me.

jrockway on Nov 13, 2022 | parent | prev | next [–]

It seems odd to run kubectl every time you open the shell. I just save the output and source it in every shell. On my machine it's 40ms to create a shell and eval the output of "kubectl completion bash". It's <10ms to "source ~/.dotfiles/compleation/kubectl".

oweiler on Nov 13, 2022 | parent | prev | next [–]

Probably much, much faster to move the command output to a separate file and sourcing that (which requires no subshell, process substitution etc.).

Myrmornis on Nov 13, 2022 | root | parent | next [–]

Btw, that's precisely the conclusion of the article.

wodenokoto on Nov 13, 2022 | prev | next [–]

Are these autocompletions dynamic? Wouldn’t it make more sense for k8 (and others) to ship a “burned in” completion file and ask users to source that?

nickjj on Nov 13, 2022 | prev | next [–]

Should this include when loading autocompletions in the title?

zsh loads in 105ms for me on a 7 year old workstation but I don't have that source command for Kubernetes' autocompletion in my zshrc. I'm only loading a few plugins such as fast-syntax-highlighting and zsh-autosuggestions. It doesn't load slower than bash in a way that I can perceive.

Nice tip on using the profiler but how do you read the profile output compared to `time zsh -i -c exit`? The blog post you linked mentions running `time zsh -i -c exit` to get the true time which is where I saw the 105ms but none of the columns in the zsh profile table add up to 105ms. If the table reports in milliseconds, the summary table up top adds up to about 41ms for the first time column.

hrbf on Nov 13, 2022 | prev | next [–]

The caching vs. update issue could be trivially addressed by running a daily cronjob to update the static completion file.

aftbit on Nov 13, 2022 | prev | next [–]

One tip if you are using zprof: it only reports time spent in function calls, not in commands run at the top level of .zshrc. Last time I profiled, I ended up binary searching by wrapping different parts of my .zshenv and .zshrc in "zinit1" and "zinit2" then tracking which one took longest. My problem turned out to be a buggy alias that was calling "curl" during construction rather than when it was called.

hn92726819 on Nov 13, 2022 | prev | next [–]

Since nobody has mentioned a tip for his cache problem: I would just solve this with cron. Run it daily and just write the file at 5am then forget about it. Could also spawn a subshell at login to generate the file in the background

This article reminds me of my shellrc which used to have a progress bar. I had it print \r{##..}, with increasing number of # after every big source (2-3 second start. Looking back I don't know how I used that daily

mikelward on Nov 13, 2022 | parent | next [–]

They did here: https://news.ycombinator.com/item?id=33582027

hn92726819 on Nov 13, 2022 | root | parent | next [–]

Whoops! I missed this, thanks

vbezhenar on Nov 13, 2022 | prev | next [–]

Can also use zcompile to further improve loading speed (not sure if measureable, but I did it for the sake of it).

cb321 on Nov 13, 2022 | parent | next [–]

It is quite measurable. Some details. At the top of .zshenv

```
    zmodload zsh/datetime
    [[ -v ZSH_TIME_STARTUP ]] && t0=$EPOCHREALTIME

```

 and at the bottom of .zshrc

```
    [[ -v ZSH_TIME_STARTUP ]] && echo $[EPOCHREALTIME-t0]

```

 This is better than alternatives mentioned here which also time .zlogout - i.e. start up & shut down. Now, when I do something like

```
    (repeat 20 ZSH_TIME_STARTUP= zsh -il -c exit)|sort -g|head -n5|mnsd

```

 I get

```
    0.03635 +- 0.00034

```

 Now if I

```
    rm .zcompdump.zwc digraphs.zsh.zwc

```

 and then repeat the "mean,std.dev of best 5 out of 20" above, I get

```
    0.07270 +- 0.00015

```

 So, basically 2x faster start up time by just by doing zcompile on those two files. Also, if I re-run the (repeat..) then I get numbers within +- 2..3 std.devs. So, the numbers and run-to-run consistency all get along fine.

spockz on Nov 13, 2022 | parent | prev | next [–]

How would you use zcompile? The help page reads to me I need to point it at a file. But which one? .zshrc?

cb321 on Nov 13, 2022 | root | parent | next [–]

A good way to isolate which work is causing slowness is the PS4 variable. This is what is printed in "-x" tracing mode. E.g.:

```
    PS4='+$EPOCHREALTIME ' zsh -ilx -c exit 2>/t/zpro

```

 You need to have `zmodload zsh/datetime` loaded early for that to work..E.g. at the very top of your .zshenv.

It's not hard to do a little post-processing script to have awk do entry-to-entry deltas on that /t/zpro file and then sort those to get a "seconds cmd" kind of report. Personally, I have found this more effective at identifying hotspots than the zprof mentioned in the article.

EDIT: Caveat - There can be a bit of a Heisenberg style disturb what you are measuring effect from trace overheads. For example, the `_comps = (32 kiB report)` always shows up as the most expensive thing for me, but I think that 3.3ms comes mostly from the `-x` just printing the thing out after the timestamp or maybe formatting it for print. If I just do a t0=$EPOCHREALTIME before and echo $[EPOCHREALTIME-t0] after it takes only 1.0 ms in non-traced mode. So, 2.3/3.3 = 70% of the time is just the formatting/printing/-x work.

johnnypangs on Nov 13, 2022 | prev | next [–]

I really enjoy zr(at). I don’t think it will help with specific completions that are slow to load though, but it’s simple, easy to use and can be pretty bare bones.

https://github.com/jedahan/zr

voidz on Nov 13, 2022 | parent | next [–]

Great tip! zr seems very useful.

theptip on Nov 13, 2022 | prev | next [–]

I suppose this is something that Nix would excel at; just inspect the hash of kubectl (or whatever you are running completions for), and reinstall a downstream derivation that caches the completions of it changes.

doublepg23 on Nov 13, 2022 | prev | next [–]

Anyone know the best way to clean up your shell init scripts? Maybe rephrased a better way - what are all files my shell sources on startup? (fish in this case.)

jmclnx on Nov 13, 2022 | prev | next [–]

There you go, large init files = slower loads :)

I setup zsh to work like my tcsh setup to give it a try and used it for a while. Yes the init files in zsh are a bit larger, but I noticed no speed difference at all. In the article it seems they are loading all kinds of things. So I would expect zsh would be slower.

BTW, I am still on tcsh only due to my "muscle memory" and on history the cursor positions at the end of the line instead of the beginning.

cb321 on Nov 13, 2022 | parent | next [–]

Besides large init files, another way to get slow start ups is large history files. I used to set mine to hundreds of thousands of entries until I realized this was slowing down start up time by a factor of several. :-)

iudqnolq on Nov 13, 2022 | root | parent | next [–]

There's always the variety of sqlite history extensions

jck on Nov 13, 2022 | prev | next [–]

You can use a plugin manager like https://github.com/marlonrichert/zsh-snap to cache the output of these commands. Using something like the packages version number as the cache key will ensure that it gets regenerated only once per package update as opposed to every shell launch.

dezzadk on Nov 13, 2022 | prev | next [–]

This tip beats all tips https://asciinema.org/a/274255

You can move the line below your bindkey defs so you still have keys.

vbezhenar on Nov 13, 2022 | parent | next [–]

Excerpt from script comments:

This doesn't actually make your zsh start instantly, hence the reference to the "one weird trick" advertisement. It does, however, make it feel like zsh is loading faster. Or, put it another way, your original zsh wasn't so slow to load, but you thought it was slow. Now you see that it was pretty fast all along.

Here's how it work. To make your zsh "start instantly" all you need to do is print your prompt immediately when zsh starts, before doing anything else. At the top of ~/.zshrc is a good place for this. If your prompt takes a long time to initialize, print something that looks close enough. Then, while the rest of ~/.zshrc is evaluated and precmd hooks are run, all keyboard input simply gets buffered. Once initialization is complete, clear the screen and allow the real prompt be printed where the "loading" prompt was before. With the real prompt in place, all buffered keyboard input is processed by zle.

It's a bit gimmicky but it does reduce the perceived ZSH startup latency by a lot. To make it more interesting, add `sleep 1` at the bottom of zsh and try opening a new tab in your terminal. It's still instant!

dezzadk on Nov 13, 2022 | root | parent | next [–]

True, however at some point you have plugins that take near 1s to load like syntax highlighting and its just not possible to reduce that to 100ms

ilyt on Nov 13, 2022 | root | parent | prev | next [–]

I just start typing command before prompt shows...

hk1337 on Nov 13, 2022 | prev | next [–]

Using zsh now but I had a similar issue with bash-it and it turns out the culprit was that I was running brew —prefix multiple times to get the home brew path instead of using an environment variable.

hfjcic7 on Nov 13, 2022 | prev | next [–]

It doesn't. You've loaded it up with omz.

ibejoeb on Nov 13, 2022 | prev | next [–]

I also had a problem with startup time using zsh. Then I switched to fish. Now I really have a problem...

1letterunixname on Nov 14, 2022 | prev | next [–]

I use powerlevel 10k which does asynchronous startup. It has a cache script that runs early.

bArray on Nov 13, 2022 | prev | next [–]

I think zsh and others (bash, ash, etc) are a problem for many reasons:

1. Poor start-up time. It's not so much a problem if you are opening a terminal, but if you're running shell scripts in a large loop, they could soon become a significant factor of your run time.

2. Too much RAM. I'm looking at my server and bash is taking 2-3MB per script. When you're running a 10's or maybe 100's of little scripts this really adds up.

3. The syntax is wrong. For example in bash, there are more ways to write a loop that I can to mention. Often I find myself wondering if I need no brackets, [], [[]], (), (()) - it really shouldn't be this hard or varied.

4. Proper types. Sometimes you simply don't know if what you have can be parsed as an array or not, or whether you have a string representation of a number.

I haven't yet thought of a better way though. For example, it does a few things right:

1. Piping is really powerful. Where possible I use '|' as it's usually the simplest to understand, when you have multiple arrows < > with numbers on the end it can take a moment to figure out what gets passed where.

2. 'Forking' is super simple. Just throwing an '&' at the end means the command no longer blocks, super cool. I think I would like to see some form of "join" and I know this is possible, but it would be cool if there was a super simple syntax for this too.

Maybe:

```
    pid=$(some command &) # & would return a PID number
    # some time later
    join $pid # How would you know if the PID wasn't re-used?

```

 3. No compilation is great for writing scripts and maintaining portability.

4. The completion saves loads of time. Being able to type 'ls' and tab a few times is great for finding where something is or an option for a command. In the same strength, the history accessible with arrow keys is also really cool.

One thing that could save some time during startup is to have a spare shell already spun up and waiting to be allocated. This would cause some issues with sourcing, but it could be possible to check the timestamps on the sourced files and see whether they require another source just before handing the process over. It's a little hacky though and a better solution would still be to address the performance issues directly.

SAI_Peregrinus on Nov 13, 2022 | parent | next [–]

> 3. The syntax is wrong. For example in bash, there are more ways to write a loop that I can to mention. Often I find myself wondering if I need no brackets, [], [[]], (), (()) - it really shouldn't be this hard or varied.

If you want even weirder syntax, just never use square brackets. Write out `test` commands manually. E.g. instead of `if [ ${string1} = ${string2} ]; then` write `if test ${string1} = ${string2}; then`. `[` is just an alias for `test`. Combining comparisons can get a bit harder to keep track of though, since there's no `]` and `test` allows logical operations with `-a` and similar. Better to call `test` multiple times and use the shell-native `&&` and similar IMO.

hyperhopper on Nov 13, 2022 | parent | prev | next [–]

If you're worrying about loop syntax and types in your Shrek script, you probably should be using a real programming language language instead

bArray on Nov 14, 2022 | root | parent | next [–]

I don't think a clean script is much to ask for. Sometimes a programming language is not particularly appropriate. There's some middle ground where it's complex, but re-writing it in a programming language is a super pain.

ykonstant on Nov 13, 2022 | root | parent | prev | next [–]

Somebody once told me the buffer's overflowing

loops ain't the sharpest tool in the shell.

pedro84 on Nov 13, 2022 | parent | prev | next [–]

RE: #2, would "wait $(jobs -rp)" work for you?

bArray on Nov 14, 2022 | root | parent | next [–]

You learn something new every day. I had a quick look [1], seems quite usable!

[1] https://www.linuxjournal.com/content/job-control-bash-featur...

FBISurveillance on Nov 13, 2022 | prev | next [–]

Pro tip: add `zmodload zsh/zprof` at the beginning of your zshrc and `zprof` at the end, open a new shell to see those pesky long-loading sources as a nicely formatted trace with timings.

greymalik on Nov 13, 2022 | parent | next [–]

That’s covered in TFA.

csdvrx on Nov 13, 2022 | root | parent | next [–]

The core problem is using too many modules, and frameworks like oh-my-zsh look good, but don't give you much visibility on the internals.

When I was using MSYS2 (cygwin based, so with a slow fork) I ended up writing my own solution for a cute prompt and history logging to sqlite with a fzy frontend because the existing solutions were all made for Linux and assumed among other things fast forks.

suprfnk on Nov 13, 2022 | parent | prev | next [–]

This is in the article:

> the tl;dr is to add zmodload zsh/zprof add the very top of your ~/. zshrc and zprof to the very bottom, then restart the shell. On startup, you will see a table with everything impacting your shell startup time.

FBISurveillance on Nov 13, 2022 | root | parent | next [–]

Ah yes, I wanted to play GPT-3 and posted what I think the summary is here as a comment.

jokethrowaway on Nov 13, 2022 | prev | next [–]

Moved to fish because of this but I'm annoyed at all the incompatibilities

1letterunixname on Nov 14, 2022 | parent | next [–]

Which "incompatibilities"?

raydiatian on Nov 13, 2022 | prev | next [–]

Glad I’m not the only one that finds Zsh slow to start

mikelward on Nov 13, 2022 | parent | next [–]

Zshrc is slow if you put slow things in it.

In the article, the author was running kubectl in their zshrc. kubectl was slow. This doesn't prove zsh is slow.

raydiatian on Nov 13, 2022 | root | parent | next [–]

My wording is pretty clear, that’s no claim to have proof. My working understanding is that .rc files are common for shell init. If it turns out that .rc files slow down any shell du jour significantly, then TIL, I don’t know much about the inner workings of shells and haven’t had a practical reason to learn.

In any case, I’d like to apologize because I clearly offended you somehow, despite being a fellow zsh user and for that I am sorry.

mkonecny on Nov 14, 2022 | root | parent | next [–]

You may as well have said "Im glad im not the only one who noticed Linux/Mac OS is slow" or Intel/AMD is slow or bash/fish/ksh is slow

My working understanding is that a program is common to run on these OS'es/hardware/shells :/

raydiatian on Nov 14, 2022 | root | parent | next [–]

I am glad I’m not the only one who noticed Linux/Mac OS is slow

hn92726819 on Nov 13, 2022 | parent | prev | next [–]

The title is misleading as it has nothing tk do with zsh being slow.

He basically had a sleep statement in his .zshrc and removed it.

raydiatian on Nov 14, 2022 | root | parent | next [–]

Whether or not the title is misleading, my experience is that my zsh loads slowly. You are downvoting me for sharing my genuine real world experience with a program. I’m sorry I hurt your feelings with my real life.

hn92726819 on Nov 21, 2022 | root | parent | next [–]

My feelings? Your comment demonstrated a misunderstanding of the article. Also I don't have enough karma to down vote anyone on hackernews.

If your zsh is slow to start, I suggest commenting your entire zshrc and then binary searching it to see what's slow (uncomment the top half only, then bottom half, then the top half of the slow half).

raverbashing on Nov 13, 2022 | prev [–]

Interesting. I assumed it was because it always pinged GitHub(?) for updates

But yeah, caching static source scripts should help

mattgreenrocks on Nov 13, 2022 | parent [–]

I think that’s oh-my-zsh, not zsh itself.

Stuff like this is why I’m not a big fan of OMZ: it clouds people’s perceptions of what zsh is/isn’t.
```

---

### The problem I have with nvm is speed (running it at shell startup introduces a v... | Hacker News
**URL:** https://news.ycombinator.com/item?id=18987472

```text
The problem I have with nvm is speed (running it at shell startup introduces a v... | Hacker News

The problem I have with nvm is speed (running it at shell startup introduces a very noticeable delay), and integration with other shells - it's always been a pain to get it running with fish.

I generally use only a single node version, and therefore don't use the nvm command much, so I've solved the slow shell init by not loading nvm at all, and instead, just set the PATH.

```
    export PATH=~/.nvm/versions/node/v11.6.0/bin:$PATH

```

Downside is that you have to bump the version occasionally but it's worth the fast shell startup.

I currently have this problem on my zsh setup - is there any easy fix for it?

idk about zsh, but for fish there is https://github.com/FabioAntunes/fish-nvm which delays executing nvm until you use one of the node binaries. Essentially, node is aliased to `nvm activate && node`
```

---

### I adore fish and can't imagine ever switching back to zsh or bash. First, it's n... | Hacker News
**URL:** https://news.ycombinator.com/item?id=41526577

```text
I adore fish and can't imagine ever switching back to zsh or bash. First, it's n... | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

kstrauser on Sept 12, 2024| parent| context| favorite| on: Reasons I still love the fish shell

I adore fish and can't imagine ever switching back to zsh or bash. First, it's nice and usable out of the box with a huge set of pre-configured completions. Second, it's incredibly easy to customize when I do want to tweak it.

For instance, writing my own prompt was what forever won me over from zsh. Basically, you edit a file named `~/.config/fish/functions/fish_prompt.fish`. That's where autoload functions live. If you type `foo` at the command line and it doesn't already exist, fish will look for a file named `foo.fish` in that directory, load it, and run the `foo` function defined there.

So in your editor, follow that pattern to write a function named `fish_prompt`. Put the commands in there that write your prompt to stdout. Make it as simple or complex as you want.

There. Done. That's all you have to do. Compare these:

Official fish docs: https://fishshell.com/docs/current/prompt.html

Official zsh docs: https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.htm

Anyway, that was emblematic of my whole experience with fish. It took a lot of un-learning special magic to settle in. It just feels so much more cohesive and consistent than any other shell I've tried. And because of that, I'm way quicker to add little scripts or completions to it that make it even more pleasant for me. I'd say the activation energy for that is far lower than with other shells I've used.

For context, I maintained the FreeBSD "bash-completion" port from 2003 to 2008 or so. It's not that I love fish because I don't know the alternatives. I love it because I do.

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### Hey all, one of the fish devs here. It's awesome to see all of the comments and ... | Hacker News
**URL:** https://news.ycombinator.com/item?id=15911437

```text
Hey all, one of the fish devs here. It's awesome to see all of the comments and ... | Hacker News

Hey all, one of the fish devs here. It's awesome to see all of the comments and happy users.

We are in the process of scoping a major release (fish 3.0) that can include major syntactic changes. If there's an aspect of fish you would like to see changed, now is a great time! Of course we'll read the comments here, and our issues page [1] is where discussion happens.

We're also welcoming new contributors. It's easy to get started writing completions or with the issues labelled "easy-pick". The core code base is reasonably modern C++ too.

I see that https://github.com/fish-shell/fish-shell/issues/3341 is scheduled for 3.0. This is also marked as the fix for the broken/invalid YAML format that is used for storing the shell history https://github.com/fish-shell/fish-shell/issues/2258

I implore you to NOT use JSON or ProtocolBuffers, neither are appropriate formats for configuring my shell, or storing long sets of textual data. Protocol Buffers is hardly the kind of format I want to parse and read my history in, and JSON is a less than ideal configuration format for many reasons.

https://github.com/vstakhov/libucl UCL (Universal Configuration Language) is a much more appropriate format for configuring programs than JSON, and is has been accepted as standard for use configuring all tools included in the FreeBSD operating system.

I also suggest you consider using a different language to store shell history, since shell history and shell configuration are two very different jobs with different goals and trade offs. I personally would suggest a simple safe format like TOML https://github.com/toml-lang/toml for storing the history.

But If you do want a single format for both configuration and history, I would implore you to pick TOML not JSON or Protocol Buffers.

Supporting this, I don't think protobuf is a good format for storing history files. Backward compatibility is tricky with it - I don't think the history format is going to change all that much, but I think there were changes in history of fish shell like adding time field. If the choice would be on a binary format, I would much, much, much more prefer SQLite for that. Also, B-trees are perfectly fine choice for searching history, as they make prefix searches trivial.

TOML is definitely an interesting choice if a text format is deemed necessary however. Array of tables syntax should be a fine syntax choice for storing history.

I was about to say SQLite, it seems perfect - binary, fast, easy to update cheaply in place, immune to escaping et al problems (if you use prepared statements, not glue SQL with + of course), reliable, available in most languages (even for C and C++ the integration is trivial - it's a single pair of files drop in) and on the CLI, stable, the history data is very row/item oriented and not totally heterogeneous or free form, etc.

I totally drank the SQLite koolaid a long time ago.

History file may be read & updated simultaneously my multiple processes. Is that sufficiently safe from corruption with SQLite? (honest question, no FUD implied. same risks apply to alternatives too.)

Yes, SQLite has robust multiprocess locking and transaction support. https://sqlite.org/faq.html#q5

In addition protobuf is designed for communications, not incremental updates in a local store. As such making things robust to store things on a development machine is non-trivial. SQLite is so much better for that. After Firefox switched to use it for its own history, most problems with history corruption disappeared.

You can ad extra fields to protobufs just fine, they just need to be added to the end of the definition.

Out of the mainstream formats, JSON is among the easiest to parse - thanks to the CLI tool jq. Does UCL have something equivalent?

Protobuf (or any other binary format) has the benefit of being faster to load, but I agree - it should not be be used to store things like history. It should be easy to parse history without having to write code. And with Protobuf, you need the schema.

If a binary format is going to be used, it should be optional - or perhaps there should be tools to convert the history file to/from a plaintext format.

There is uclcmd [https://github.com/allanjude/uclcmd] which could do with some more work but was created with the intent of being a UCL equivalent of JQ.

Also since he’s the kind of person that a HN reader will probably Ike to know more about. The original author of the aforementioned uclcmd, Allan Jude [http://twitter.com/allanjude], is the former host of the TechSNAP podcast [http://www.jupiterbroadcasting.com/show/techsnap/], current host of the BSD Now podcast [http://www.jupiterbroadcasting.com/show/bsdnow/], a current member of the FreeBSD Core team, and co-authored not one but two books on the ZFS file system FreeBSD Mastery: ZFS [https://www.amazon.com/FreeBSD-Mastery-ZFS-7/dp/0692452354/] and FreeBSD Mastery: Advanced ZFS [https://www.amazon.com/FreeBSD-Mastery-Advanced-ZFS/dp/06926...]

Would like to see comments in configuration, Json doesn't support comments.

UCL can be trivially transformed to JSON or YAML; ucl-tool supports this from CLI.

Thanks for writing that up, I linked to it from the issue. FWIW I agree with you that shell history should be a simple format, and even ad-hoc parseable via Unix tools. zsh uses simple : and ; delimiters. JSON is more complex, and binary formats like protobuf are way out.

Long-time fish user here, I'll second this comment and implore that you choose TOML for the configuration format. TOML format is easy for users to understand, and well-written parsers for it exist in every programming language.

For configuration I would very much prefer to have something that can be properly grepped/patched/generated with shell scripts if necessary. What openssh uses for its config mostly fulfill this, but ini file also are not that bad. Anything hierarchical like JSON/TOML/UCL etc. becomes very unattractive the moment one has to patch them from automated setup scripts.

There pretty mighty tools around to grep/patch/generate JSON data with shell scripts and they are made to deal with hierarchical data.

Both are single binaries, so easy to run them where you need it. I don't know comparable stuff for the other mentioned formats, whenever I need to deal with yaml in scripts i run

I would be totally fine with any format that can be converted to JSON on the fly. Of course I would love to have something like these tools more integrated within a shell, but the representing text format on the disk is not that important for me.

Templates in configuration management can help with this a bit.

Thanks for bringing up UCL! Hadn't seen that before but I definitely need to try this in a few places.

Fish shell's design doc [0] was a huge inspiration in the design of pgcli [1] and mycli [2].

Thank you for leading the charge on modern command line design.

Credit where credit is due, nearly all of the design doc was written by Axel Liljencrantz, the author of fish 1.x.

Does this mean... the link between the name and your nick is a coincidence?

Thanks for both your work on fish and for your blog!

I am learning Postgresl for the fun of it and I hadn’t heard of pgcli before. Thanks for mentioning it.

pgcli was a huge help to some former colleagues who had some trouble working with relational databases and SQL for the first time. I'm a big fan myself as well. Thank you for building a great piece of software.

Copy and pasted from another reply: "I still wish fish support && and ||, if only for the times when I copy and paste some one-liner off of stack overflow and have to rewrite it."

That and support for

```
    SOME_ENV_VAR=foo ./bar

```

(not having to prepend "env ") are what's stopping me from recommending fish to others.

Btw: Big thank you for fish, it's awesome!

I really like that you have to use `env` in fish, since it's cross-shell - it works in bash/zsh/dash/whatever. The `A=b foo` syntax is an unnecessary appendix in the syntax that complicates matters while only saving 4 characters.

It's not just to save typing - having an `A=b foo` form built-in instead of relying on an external program means `foo` can be an alias or shell function.

I agree and think the best fix would be if the syntax would be forbidden in bash/zsh. Problem is: Millions of code snippets on the Internet not using env.

For one-liners, typing `env ` before pasting is likely not too much work. For longer scripts, you'd have to rewrite much of the text anyway.

often there's stuff like

```
    cd build && LD_LIBRARY_PATH=../lib ./foo

```

:/

It's no dealbreaker though, I still use fish and love it :) Just a minor annoyance ;)

That syntax is from very early days of sh itself (predecessor of bash), IIRC. So removing it would break many scripts, as sibling comment by jhasse said.

Agree with these, and would like to add one more:

```
  $(subcommand)

```

as an alternative to

```
  (subcommand)

```

PS: I have been using fish as my primary shell for about a year now, very happy with it. :)

Good news: Another dev mentioned that they are already discussing this: https://news.ycombinator.com/item?id=15913358

Yes please, even if we have to opt in to this behavior with a patronizing env var :)

While I like fish, I stopped using it because of a small convenience feature ZSH has.

With ZSH, I can run a command with a space at the start so it's excluded from history, even though its not saved to disk, the last command is still stored in memory so I can press Up to access it again.

This is handy when a mistake is made in the command means I need to run it again with some small change.

A large number of electrons have been expended on this topic - see https://github.com/fish-shell/fish-shell/issues/4327 for a starting point. It doesn't seem there's a perfect answer here.

Heh I have the opposite preference, I use space to ensure when pressing up it will not bring up that command, to not mistakingly run it when muscle memory will expect another command there (for mv and rm commands mostly)

This feature seems to exist also in bash. I discovered it accidentally while wondering why my history did not include my last commands (copy/pasted with a leading space).

AFAIK it's not stored in history but also you can't go "up" and run it again which is what parent wants.

Right, only the last command is kept in memory. Run another command and it's lost (which is good IMHO)

I tried fish and it seemed ok, I didn’t continue with it cause I needed to rewrite all my aliases and functions (work related not at home). From memory one was && vs “and” which we use a lot to chain commands. Something like implementing &&/|| would go a long way, compat command sub, closing if statements . I know it seems like a small thing to modify your aliases/functions but I would basically need to modify mine and be a maintainer for the shared ones. TLDR adddition transitionally compat with bash or zsh

If there is anything I would personally like to see it’s the bass plugin rolled into the shell itself to make transitions for bash and some esoteric edge cases easier to handle https://github.com/edc/bass

Maybe adopt a package manager for plugins too? ;)

Regarding the package manager, you should check out https://github.com/fisherman/fisherman

I would love to see zsh navigation tools[0] be integrated in fish. There is a long standing issue in fish which is the support for CTRL-R history, while many are pondering on the UI of it. I would like to see znt's UI be adopted (not saying it's perfect, but quite a good starting point for user conversion).

I have switched to fzf for Ctrl-R history which does seem kind of similar.

Avid fish user since last 3 years. On feature I miss from bash is the `sudo !` to re-run previous command as sudo. Last time I checked fish didn't offer an equivalent. Either that or something similar will be useful

This is easily achieved using a fish function: https://github.com/nyarly/fish-bang-bang

Unlike bash, fish even expands it in place, allowing you to make changes.

zsh also expands in place for double bang, as well as the ^match^replace thing, too. Probably others, but those are the only ones I use regularly.

I missed it too, so I created a fish function:

``` function sudo if test "$argv" = !! eval command sudo $history[1] else command sudo $argv end end ```

This works for `sudo !!`

Up, Home, "sudo "

Only one more key press than "sudo !" :)

I use up, ctrl-a, then type "sudo ".

!! and !$ are the two miss most.

but similarly, fish user for the last 2+ years.

With !$ you can use Alt+. to write the arguments from the last command.

Alt+. is a bash (libreadline really) key.

In fish Alt+Up does something similar, but repeated presses iterates over all words of all commands rather than last words of bash commands. A big improvement is you can type some chars first and then Alt+Up only gets words matching this substring — like Up but word granularity! (Closest bash key is Ctrl+Alt+I)

If you don't mind the differences, and want Alt+. muscle memory to work in fish too, do:

```
 bind \e. history-token-search-backward

```

(plus Alt+Up doesn't work for me in linux console, Alt+. does)

Hey, thank you for contributing to one of my favorite pieces of software :) The Fish shell is my primary choice, because it's so intuitive and easy to use. I never encountered a situation where the Fish shell behaved contrary to my expectations. I do wish there was a native Windows version, because that's where I spend 50% of my digital time, but only because it's so great.

Two things I personally eager to see:

1. equivalent of `set +x` and `set +e` from bash (to echo commands and stop script execution on the first non-zero return) – https://github.com/fish-shell/fish-shell/issues/3427,

2. Associative arrays – https://github.com/fish-shell/fish-shell/issues/390

&& is a major one. Also !! for sudo !!

Fish's FAQ already explains why it doesn't use `!!` – it says that editing commands from history by pressing the up arrow is more memorable and flexible. I don't find it a problem to type “up Ctrl-A sudo” instead of “sudo !!”.

It would be great if Fish supported &&. I know it has its own syntax for this but it's not particularly fun going through a command you copy pasted from elsewhere and swapping out all the &&s (I usually just end up firing up bash).

Care to explain what this does? Thanks

!! is the last command, so sudo !! will run the last command as root.

e.g. apt install foo # you need root permissions to install, won't work sudo !! # will expand to sudo apt install foo, and it'll work!

Thanks for it! I am also using Fish happily for interactive terminal work. Not so much for scripting as I am lazy to learn the new syntax.

What I don't like is that after hitting Tab twice when doing path completion, the list of possibilities comes out, allowing arrow keys to be used for selection. The problem is that it requires pressing Enter to confirm the suggestion and I fear of executing the command with incomplete path prematurely (it's just one more Enter hit away).

What sort of syntactic changes?

Hi, another fish dev here!

We're open to a lot of things (except "make it fully POSIX-compatible"). We're still trying to not massively break everything, though.

The sort of things we've discussed include:

- Not expanding `{}` so you don't need to quote it with e.g. `find -exec {}` (currently this is read as a zero-element brace expansion, i.e. it expands to no argument)

- Removing the `?` single-character glob because it's apparently entirely unused and is another special character to remember (in fact we've also talked about removing `^` as a shorthand for redirecting stderr and `%something` process expansion)

- Allowing `$(command)` command substitutions, which could be used inside quotes as well (long term, these would replace our current `(command)` style)

- Possibly removing the special handling we have for $PATH, $CDPATH and $MANPATH (these are treated by fish as lists, which is nice in some ways and causes pain in others)

For a general overview, see [the fish 3.0 milestone on github](https://github.com/fish-shell/fish-shell/milestone/18).

No thanks, am happy with the shell as is.

I'm very glad to see that getting rid of the magic path variable semantics is a possibility for 3.0 :)

Other than that, my biggest pain point with fish now is that it doesn't interact well with pkg-config (issue #982) and the workarounds for that are a bit awkward. eval is scary and may require double-quoting the non-pkg-config parameters, and string splitting can wrongly split inside quoted text.

Is there any planned work on the vi-mode command line edition ? This is the sole missing feature which make me miss bash from time to time.

Vi mode has been implemented since 2.2.0 (July 2015), although it's an ongoing work in progress - if there's something missing then we'd consider adding it (although nobody's going to reimplement Vim in fish - sometimes Alt-E is your best option).

Sure, but the current implementation has several bugs and could be refined, some motion command does not move where is expected (ie e b e b combos)

the main feature i use fish for is the syntax expansion, and history usage of it. The biggest gripe i have with it is the specific syntax. If fish would act more like a bash shell in case of syntax. ( i know i would need a totally different shell). But it could replace the fish for me in an instant. everywhere. Anyways. Thanks for the fish.

What are some things to look forward to for Fish 3.0?
```

---


## 5. Toolchain & Version Manager Overheads (conda, nvm, etc.)

### One of my biggest points of criticism of Python is its slow cold start time. I e... | Hacker News
**URL:** https://news.ycombinator.com/item?id=46230192

```text
One of my biggest points of criticism of Python is its slow cold start time. I e... | Hacker News

One of my biggest points of criticism of Python is its slow cold start time. I especially notice this when I use it as a scripting language for CLIs. The startup time of a simple .py script can easily be in the 100 to 300 ms range, whereas a C, Rust, or Go program with the same functionality can start in under 10 ms. This becomes even more frustrating when piping several scripts together, because the accumulated startup latency adds up quickly.

Yes, that is also my feeling. But comparing an interpreted language with a compiled one is not really fair.

Here is my quick benchmark. I refrain from using Python for most scripting/prototyping task but really like Janet [0] - here is a comparison for printing the current time in Unix epoch:

```
    $ hyperfine --shell=none --warmup 2  "python3 -c 'import time;print(time.time())'" "janet -e '(print (os/time))'"
  Benchmark 1: python3 -c 'import time;print(time.time())'
  Time (mean ± σ):      22.3 ms ±   0.9 ms    [User: 12.1 ms, System: 4.2 ms]
  Range (min … max):    20.8 ms …  25.6 ms    126 runs

  Benchmark 2: janet -e '(print (os/time))'
  Time (mean ± σ):       3.9 ms ±   0.2 ms    [User: 1.2 ms, System: 0.5 ms]
  Range (min … max):     3.6 ms …   5.1 ms    699 runs

  Summary
  'janet -e '(print (os/time))'' ran
    5.75 ± 0.39 times faster than 'python3 -c 'import time;print(time.time())''

```

Well python is also compiled technically.

> The startup time of a simple .py script can easily be in the 100 to 300 ms range

I can't say I've ever experienced this. Are you sure it's not related to other things in the script?

I wrote a single file Python script, it's a few thousand lines long. It can process a 10,000 line CSV file and do a lot of calculations to the point where I wrote an entire CLI income / expense tracker with it[0].

The end to end time of the command takes 100ms to process those 10k lines, that's using `time` to measure it. That's on hardware from 2014 using Python 3.13 too. It takes ~550ms to fully process 100k lines as well. I spent zero time optimizing the script but did try to avoid common pitfalls (drastically nested loops, etc.).

> I can't say I've ever experienced this. Are you sure it's not related to other things in the script? I wrote a single file Python script, it's a few thousand lines long.

It's because of module imports, primarily and generally. It's worse with many small files than a few large ones (Python 3 adds a little additional overhead because of needing extra system calls and complexity in the import process, to handle `__pycache__` folders. A great way to demonstrate it is to ask pip to do something trivial (like `pip --version`, or `pip install` with no packages specified), or compare the performance of pip installed in a venv to pip used cross-environment (with `--python`). Pip imports literally hundreds of modules at startup, and hundreds more the first time it hits the network.

Makes sense, most of my scripts are standalone zero dependency scripts that import a few things from the standard library.

`time pip3 --version` takes 230ms on my machine.

That proves the point, right?

`time pip3 --version` takes ~200ms on my machine. `time go help` takes 25, and prints out 30x more lines than pip3 --version.

Yep, running time on my tool's --version takes 50ms and funny enough processing 10k CSV lines with ~2k lines of Python code takes 100ms, so 50ms of that is just Python preparing things to run by importing 20 or so standard library modules.

> so 50ms of that is just Python preparing things to run by importing 20 or so standard library modules.

Probably a decent chunk of that actually is the Python runtime starting up. I don't know what all you `import` that isn't implied at startup, though.

Another chunk might be garbage collection at process exit.

And it's worse if your python libraries might be on network storage - like in a user's homedir in a shared compute environment.

Exactly this. The time to start python is roughly a function of timeof(stat) * numberof(stat calls) and on a network system that can often be magnitudes larger than a local filesystem.

I do wonder, on a local filesystem, how much of the time is statting paths vs. reading the file contents vs. unmarshaling code objects. (Top-level code also runs when a module is imported, but the cost of that is of course highly module-dependent.)

Maybe you could take the stat timings, the read timings (both from strace) and somehow instrument Python to output timing for unmarshalling code (or just instrument everything in python).

Either way, at least on my system with cached file attributes, python can startup in 10ms, so it's not clear whether you truly need to optimize much more than that (by identifying remaining bits to optimize), versus solving the problem another way (not statting 500 files, most of which don't exist, every time you start up).

Here is a benchmark https://github.com/bdrung/startup-time

This benchmark is a little bit outdated but the problem remains the same.

Interpreter initialization: Python builds and initializes its entire virtual machine and built-in object structures at startup. Native programs already have their machine code ready and need very little runtime scaffolding.

Dynamic import system: Python’s module import machinery dynamically locates, loads, parses, compiles, and executes modules at runtime. A compiled binary has already linked its dependencies.

Heavy standard library usage: Many Python programs import large parts of the standard library or third-party packages at startup, each of which runs top-level initialization code.

This is especially noticeable if you do not run on an M1 Ultra, but on some slower hardware. From the results on Rasperberry PI 3:

C: 2.19 ms

Go: 4.10 ms

Python3: 197.79 ms

This is about 200ms startup latency for a print("Hello World!") in Python3.

Interesting. The tests use Python 3.6, which on my system replicates the huge difference shown in startup time using and not using `-S`. From 3.7 onwards, it makes a much smaller percentage change. There's also a noticeable difference the first time; I guess because of Linux caching various things. (That effect is much bigger with Rust executables, such as uv, in my testing.)

Anyway, your analysis of causes reads like something AI generated and pasted in. It's awkward in the context of the rest of your post, and 2 of the 3 points are clearly irrelevant to a "hello world" benchmark.

A python file with

```
    import requests

```

Takes 250ms on my i9 on python 3.13

A go program with

```
    package main
    import (
       _ "net/http"
    ) 
    func main() {
    }

```

takes < 10ms.

This is not an apples-to-apples comparison. Python needs to load and interpret the whole requests module when you run the above program. The golang linker does dead code elimination, so it probably doesn't run anything and doesn't actually do the import when you launch it.

Sure it's not an apples to apples comparison - python is interpreted and go is statically compiled. But that doesn't change the fact that in practice running a "simple" python program/script can take longer to startup than go can to run your entire program.

Still, you are comparing a non-empty program to an empty program.

Even if you actually use the network module in Go, just so that the compiler wouldn't strip it away, you would still have a startup latency in Go way below 25 ms from my experience with writing CLI tools.

Whereas with Python, even in the latest version, you're already looking at atleast 10x the amount of startup latency in practice.

Note: This is excluding the actual time that is made for the network call, which can of course also add quiete some milliseconds, depending on how far on planet earth your destination is.

You're missing the point. The point is that python is slow to start up _because_ it's not the same.

Compare:

```
    import requests
    print(requests.get("http://localhost:3000").text)

```

to

```
    package main

    import (
      "fmt"
      "io"
      "net/http"
     )

    func main() {
        resp, _ := http.Get("http://localhost:3000")
        defer resp.Body.Close()
        body, _ := io.ReadAll(resp.Body)
        fmt.Println(string(body))
    }

```

I get:

```
    python3:  0.08s user 0.02s system 91% cpu 0.113 total
    go 0.00s user 0.01s system 72% cpu 0.015 total

```

(different hardware as I'm at home).

I wrote another that counts the lines in a file, and tested it against https://www.gutenberg.org/cache/epub/2600/pg2600.txt

I get:

```
    python 0.03s user 0.01s system 83% cpu 0.059 total
    go 0.00s user 0.00s system 80% cpu 0.010 total

```

These are toy programs, but IME that these gaps stay as your programs get bigger

It's not interpreting- Python is loading the already byte compiled version. But it's also statting several files (various extensions).

I believe in the past people have looked at putting the standard library in a zip file instead of splatted out into a bunch of files in a dirtree. In that case, I think python would just do a few stats, find the zipfile, loaded the whole thing into RAM, and then index into the file.

> In that case, I think python would just do a few stats, find the zipfile, loaded the whole thing into RAM, and then index into the file.

"If python was implemented totally different it might be fast" - sure, but it's not!

No, this feature already exists.

Great - how do I use it?

You should look at the self-executing .pex file format (https://docs.pex-tool.org/whatispex.html). The whole python program exists as a single file. You can also unzip the .pex and inspect the dependency tree.

It's tooling agnostic and there are a couple ways to generate them, but the easiest it to just use pants build.

Pants also does dependency traversal (that's the main reason we started using it, deploying a microservices monorepo) so it only packages the necessary modules.

I haven't profiled it yet for cold starts, maybe I'll test that real quick.

Edit: just ran it on a hello world with py3.14 on m3 macbook pro, about 100 +/-30 ms for `python -m hello` and 300-400 (but wild variance) for executing the pex with `./hello/binary.pex`.

I'm not sure if a pants expert could eke out more speed gains and I'm also not sure if this strategy would win out with a lot of dependencies. I'm guessing the time required to stat every imported file pales in comparison to the actual load time, and with pex, everything needs to be unzipped first.

Pex is honestly best when you want to build and distribute an application as a single file (there are flags to bundle the python interpreter too).

The other option is mypyc, though again that seems to mostly speed up runtime https://github.com/mypyc/mypyc

Now if I use `python -S` (disables `import site` on initialization), that gets down to ~15ms execution time for hello world. But that gain gets killed as soon as you start trying to import certain modules (there is a very limited set of modules you can work with and still keep speedup. So if you whole script is pure python with no imports, you could probably have a 20ms cold start).

Just a guess - but perhaps the startup time is before `time` is even imported?

`time` is a shell command that you can use to invoke other commands and track their runtime.

It might not be the fastest but I suspect something weird is happening with python resolution.

For instance `uv run` has its own fair share of overhead.

```
    $ hyperfine --warmup 10 -L py "uv run python,~/.local/bin/python3.14,/usr/local/bin/python3.12,~/.local/share/uv/python/pypy-3.11.13-macos-aarch64-none/bin/pypy3.11" "{py} -c 'exit(0)'"
    Benchmark 1: uv run python -c 'exit(0)'
      Time (mean ± σ):      58.4 ms ±  19.3 ms    [User: 26.4 ms, System: 21.7 ms]
      Range (min … max):    48.2 ms … 138.0 ms    50 runs
    
    Benchmark 2: ~/.local/bin/python3.14 -c 'exit(0)'
      Time (mean ± σ):      13.3 ms ±   6.9 ms    [User: 8.0 ms, System: 2.5 ms]
      Range (min … max):     9.9 ms …  53.7 ms    174 runs
    
    Benchmark 3: /usr/local/bin/python3.12 -c 'exit(0)'
      Time (mean ± σ):      16.4 ms ±   7.6 ms    [User: 8.9 ms, System: 3.7 ms]
      Range (min … max):    12.2 ms …  65.2 ms    152 runs
    
    Benchmark 4: ~/.local/share/uv/python/pypy-3.11.13-macos-aarch64-none/bin/pypy3.11 -c 'exit(0)'
      Time (mean ± σ):      18.6 ms ±   7.4 ms    [User: 10.0 ms, System: 5.0 ms]
      Range (min … max):    14.4 ms …  63.5 ms    138 runs
    
    Summary
      ~/.local/bin/python3.14 -c 'exit(0)' ran
        1.23 ± 0.86 times faster than /usr/local/bin/python3.12 -c 'exit(0)'
        1.40 ± 0.92 times faster than ~/.local/share/uv/python/pypy-3.11.13-macos-aarch64-none/bin/pypy3.11 -c 'exit(0)'
        4.40 ± 2.72 times faster than uv run python -c 'exit(0)'
```

Run strace on Python starting up- you will see it statting hundreds if not thousands of files. That gets much worse the slower your filesystem is.

On my linux system where all the file attributes are cached, it takes about 12ms to completely start, run a pass statement, and exit.

Completely agree on this.

Regarding cold-starts, I strongly believe V8 snapshots are perhaps not the best way to achieve fast cold starts with Python (they may be if you are tied to using V8, though!), and will have wide side effects if you go out of the standards packages included on the Pyodide bundle.

To put some perspective: V8 snapshots are storing the whole state of an application (including it's compiled modules). This means that for a Python package that is using Python (one wasm module) + Pydantic-core (one wasm module) + FastAPI... all of those will be included in one snapshot (as well as the application state). This makes sense for browsers, where you want to be able to inspect/recover everything at once.

The issue about this design is that the compiled artifacts and the application state are bundled into one piece artifact (this is not great for AOT designed runtimes, but might be the optimal design for JITs though).

Ideally, you would separate each of the compiled modules from the state of the application. When you do this, you have some advantages: you can deserialize the compiled modules in parallel, and untie the "deserialization" from recovering the state of the application. This design doesn't adapt that well into the V8 architecture (and how it compiles stuff) when JavaScript is the main driver of the execution, however it's ideal when you just use WebAssembly.

This is what we have done at Wasmer, which allows for much faster cold starts than 1 second. Because we cache each of the compiled modules separately, and recover the state of the application later, we can achieve cold-starts that are a magnitude faster than Cloudflare's state of the art (when using pydantic, fastapi and httpx).

If anyone is curious, here is a blogpost where we presented fast-cold starts for the application state (note that the deserialization technique for Wasm modules is applied automatically in Wasmer, and we don't showcase it on the blogpost): https://wasmer.io/posts/announcing-instaboot-instant-cold-st...

Note aside: congrats to the Cloudflare team on their work on Python on Workers, it's inspiring to all providers on the space... keep it up and let's keep challenging the status quo!

Big packages shouldn’t be imported until the cli has been parsed, and handed off to main. There’s been work to do this automatically, but it’s good hygiene to avoid it anyway.

A modern machine shouldn’t take this long, so likely something big is being imported unnecessarily at startup. If the big package itself is the issue, file it on their tracker.

I don't know why people care so much about a few hundreds of milliseconds for python scripts versus compiled languages that take just ten times less.

Real question : what would you do more with the spared time ? You are that in a hurry in your life ?

Are you comparing the startup time of an interpreted language with the startup time of a compiled language? or you mean that `time python hello.py` > `( time gcc -O2 -o hello hello.c ) && ( time ./hello )` ?

I'm referring to the startup time as benchmarked in the following manner: https://github.com/bdrung/startup-time

Here's the thing - I don't really care if its' because the interpreter has to start up, or there's a remote http call, or we scan the disks for integrity - the end user experience on every run is slower.

You can run .pyc stuff “directly” with some creativity, and there are some tools to pack “executables” that are just chunked blobs of bytecode.

it depends somewhat on what you import, too. some people would sell their grandmothers to get below 1s when you start importing numpys and scikits.

The upcoming lazy import system may help with startup time…but if the underlying issue wasn’t “Python startup is slow” but rather “a specific program imports modules that take a long time to low”, it’ll only shift the time consumption to runtime.

That's totally fine, because many CLI tools are organized like `mytool subcommand --params=a,b...`, and breaking out those subcommands into their own modules and lazy loading everything (which good CLI tools already know to do) means unused code never gets imported.

You can already lazy import in python, but the new system makes the syntax sweeter and avoids having to have in-function `import module` calls, which some linters complain about.

It’s not Python runtime startup, but loading all your modules.

Use lazy/dynamic imports and you will see it drop .

Reminds me of mercurial cvs!!

Yes it's bad enough that there's a chg to (barely) improve the command laten y.

(Side note this is why jj is awesome. A `jj log` is almost as fast as `ls`).
```

---

### Start up time. You can't write cli programs if the JVM takes 100+ms to start up. | Hacker News
**URL:** https://news.ycombinator.com/item?id=6533066

```text
Start up time. You can't write cli programs if the JVM takes 100+ms to start up. | Hacker News

Touche on Oct 11, 2013 | parent | context | favorite | on: Facebook is using D in production starting today

Start up time. You can't write cli programs if the JVM takes 100+ms to start up.

Jtsummers on Oct 11, 2013 | next [–]

That's a fair issue, but also a particular use-case. Java seems to be suitable for long running apps where that 100+ms start up time is easily covered as an ammortized cost over the apps uptime. It still doesn't answer what benefit would Java have if it had been native compilation from the start versus VM (and later VM with JIT-compilation). It would not have been able to run on near the number of platforms that it initially supported if, instead of porting a VM, they'd had to support many OS/ISA pairs. The VM -> VM w/ JIT approach provided a deployment path based on incremental improvements. Initially support dozens of platforms with good enough performance, then over time improve performance on each platform. Versus initially support a handful of platforms with good performance and spend years getting the breadth of platform support.

pjmlp on Oct 11, 2013 | parent | next [–]

So what?

This was the initial way Pascal and Modula-2 were developed. P-Code and M-Code were their bytecodes.

This didn't prevent most compiler vendors to introduce native compilers and use those bytecode implementations mainly for bootstraping purposes.

Writing compilers is not that dark magic thing many think about.

Well, except when targeting x86 processors, maybe. :)

judk on Oct 11, 2013 | prev [–]

How do webservers solve this problem and why can't CLI programsw do the same? Invoking a Java program could connect to a running jvmd daemon

Jtsummers on Oct 11, 2013 | parent | next [–]

They "solve" it by being long running applications. When GP says CLI they likely mean things like grep or cat or other command line tools, not just interfaces, that tend to run in a very short time. A Java implementation would see a lot of extra time spent on just the startup. Consider writing a bash script that calls out to grep for each of a bunch of different files (an example, better ways, but go with it). Say it ran grep 100 times, jgrep at 100ms startup time would take 10s longer just on the java startup time, ignoring any other performance differences.

hansjorg on Oct 11, 2013 | parent | prev [–]

A project which does exactly that: http://www.martiansoftware.com/nailgun/
```

---


## 6. Terminal Emulator Architecture (kitty, ghostty, alacritty, single-instance)

### OMZ is fast even on my phone. It turned slow for a whole after I installed anaco... | Hacker News
**URL:** https://news.ycombinator.com/item?id=39101801

```text
OMZ is fast even on my phone. It turned slow for a whole after I installed anaco... | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

jeroenhd on Jan 23, 2024| parent| context| favorite| on: Oh My Zsh

OMZ is fast even on my phone.

It turned slow for a whole after I installed anaconda. If you use conda and your shell is slow, try commenting out the code that loads conda, because it's probably that.

nvm likes to slow things down too. Not as bad as conda, but I did add some code to delay load it.

Do you know how fish would prevent getting slowed down by external scripts in its configuration file? Or does it just not support those scripts perhaps?

mitemte on Jan 23, 2024| [–]

I switched from nvm to fnm a few years ago and have never looked back. Zero performance issues and it supports .nvmrc files.

https://github.com/Schniz/fnm

eigenvalue on Jan 23, 2024| | [–]

It's wild to me how slow conda is. Just in ordinary day to day use, with nothing weird, you sometimes need to wait insane amounts of time, even on incredibly fast systems. Whatever they're doing, it's wrong and bad.

Ingaz on Jan 23, 2024| [–]

I had exactly same experience: nvm and conda. Both are unrelated to oh-my-zsh completely: they were configured in .zshrc directly

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### Well, these days a small CLI program in Java (say, ls) starts up cold, runs, and... | Hacker News
**URL:** https://news.ycombinator.com/item?id=48102733

```text
Well, these days a small CLI program in Java (say, ls) starts up cold, runs, and... | Hacker News

pron 3 months ago | parent | context | favorite | on: If AI writes your code, why use Python?

Well, these days a small CLI program in Java (say, ls) starts up cold, runs, and terminates in ~70ms, not 1500ms, but yeah, sometimes 70ms is too long to wait for a script.

pdimitar 3 months ago [–]

People never believe me when I say it but I start noticing scripts needing 75-100ms to start. Modern hardware is ultra fast; I want my programs to make full use of it. I got no patience for tech or people who keep insisting "it's not much, it'll not kill you". Well duh, obviously it will not but that's not the point and never was. I want stuff to work between my blinking my eyes and I have achieved that hundreds of times over the course of my career.

pron 3 months ago | parent [–]

That's perfectly fine, and I totally understand people who don't want to sit and wait 70ms for their script to finish running (that 70ms is not the time it takes to start), but let's not turn a <40ms startup into 1.5s. Now, it is true that if you want to launch a minimal HTTP server in Java you may need to wait ~100ms, which may be too long for you, but is also a far cry from 1.5s.

pdimitar 3 months ago | root | parent [–]

It is, but I am still quoting what I saw before, it was not a fantasy. I don't deny it's likely better nowadays, sure, but I remain moderately skeptical because JVM is still a runtime that needs to boot.

Then again, Golang has one as well, though it does manage to start it up faster it seems.

MaxBarraclough 3 months ago | root | parent [–]

You might be interested in OpenJDK's new ability to 'cache' classes to accelerate class loading. JEP 483: Ahead-of-Time Class Loading & Linking. It doesn't persist code generated by the JIT, but can improve startup time appreciably.

From https://openjdk.org/jeps/483 :

> This program runs in 0.031 seconds on JDK 23. After doing the small amount of additional work required to create an AOT cache it runs in in 0.018 seconds on JDK 24 — an improvement of 42%.

pdimitar 3 months ago | root | parent [–]

Thank you, that's great. Back when I worked with Java this was but a pipe dream. Glad that they got to it!
```

---

### Lowering resource usage with foot and systemd
**URL:** https://news.ycombinator.com/item?id=40557770

```text
Lowering resource usage with foot and systemd | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

| Lowering resource usage with foot and systemd(rgoswami.me) |
| --- |
| 69 points by HaoZeke on June 2, 2024| hide| past| favorite| 30 comments |

chme on June 3, 2024| [–]

The title is kinda odd. "Lowering resource usage of foot with systemd" sounds more appropriate.

Not knowing that foot is a terminal emulator, I assumed that foot is some kind of improved resource manager that allows for a general lesser resource usage.

robertlagrant on June 3, 2024| | [–]

Yes - agreed.

tupolef on June 3, 2024| | [–]

I don't want to switch to Wayland for now, but I will check foot when I do.

I do the same thing with URxvt as a systemd daemon, Tmux as a transient service with systemd-run from .bashrc, and a script in i3wm to run URxvtd client or hide/get the window.

The way I use to run Tmux from a transient service locally and in ssh with the same .bashrc is nice I think. Tmux will survive the terminal and even if I close my session and come back to it:

```
  #!/usr/bin/env bash
  # ~/.bashrc: sourced by bash(1) for non-login shells.
  
  # If not running interactively, don't do anything
  case $- in
    *i*) ;;
    *) return ;;
  esac
  
  chmod 700 ~/.bashrc.d
  chmod 600 ~/.bashrc ~/.bashrc.d/*
  
  # check if we are already in a Tmux session and not in ssh then open/attach the default one
  if [[ ! "${TERM}" == "tmux"* ]] && [[ -z "${TMUX}" ]] && [[ -z "${SSH_CONNECTION}" ]] && command -v tmux 1> /dev/null; then
    # attach or start the local default Tmux session
    if systemctl --quiet $([[ $(id -u) != 0 ]]; echo "--user") is-active tmux-local-$(id -un).scope; then
      tmux -L local-$(id -un) attach-session -t local-$(id -un) ; exit
    fi
    systemd-run -q --unit tmux-local-$(id -un) --scope $([[ $(id -u) != 0 ]] && echo "--user") tmux -L local-$(id -un) new-session -s local-$(id -un) ; exit
  elif [[ -z "${TMUX}" ]] && [[ -n "${SSH_CONNECTION}" ]] && command -v tmux 1> /dev/null; then
    # attach or start the ssh default Tmux session
    if systemctl --quiet $([[ $(id -u) != 0 ]]; echo "--user") is-active tmux-ssh-$(id -un).scope; then
      tmux -L ssh-$(id -un) attach-session -t ssh-$(id -un) ; exit
    fi
    systemd-run -q --unit tmux-ssh-$(id -un) --scope $([[ $(id -u) != 0 ]] && echo "--user") tmux -L ssh-$(id -un) new-session -s ssh-$(id -un) && exit || echo 'Tmux Systemd unit failed/exited'
  
  fi
  
  # if Tmux is not installed or if we are inside a Tmux session continue the sourcing
  for file in ~/.bashrc.d/*.bashrc;
  do
    source "${file}"
  done
```

emmanueloga_ on June 3, 2024| | [–]

I never heard about it but foot is a terminal emulator with some server mode [1].

—

1: https://wiki.gentoo.org/wiki/Foot#Server_mode_configuration

HaoZeke on June 3, 2024| | [–]

Yup, I switched a few years ago from i3 (X11) to sway (Wayland) and use it to replace urxvt.

dolmen on June 3, 2024| | | [–]

I had never heard about it either.

Here is the project official repository: https://codeberg.org/dnkl/foot

eru on June 3, 2024| | | [–]

Thanks! I was wondering about that one as well.

FrostKiwi on June 3, 2024| | [–]

Really enjoyed foot! Runs along the same lines of emacs server and emacsclient.

I ended up dropping it for the same reason I dropped emacs server. There are rare edge cases which causes the server to hang and thus taking down not just one instance of your work, but all of it. Losing the resilience of multiple processes is not worth the RAM it saves, not on modern hardware.

HaoZeke on June 3, 2024| | [–]

That's a valid point. It might be more about using the right tool for the task. For example, using tmux for persistent terminal windows can help. A setup where the main compilation terminal (subFloat) and smaller terminal instances for chat/irssi/nmpc (mS) run within a tmux session ensures persistence even if foot crashes (or is killed for applying configuration updates) as noted in the post ^_^

christophilus on June 3, 2024| | | [–]

I just use it in normal / non server mode. Never had a crash. It’s still low resource and snappy enough for me.

NewJazz on June 3, 2024| | [–]

IMO the best part of the foot client/server setup is not lower memory usage, but faster terminal opening time. Starting alacritty is kinda slow. Maybe not a second, but noticeable. Starting foot standalone is definitely faster. Opening a foot window via an already running server is near instant.

vladvasiliu on June 3, 2024| | [–]

> Starting alacritty is kinda slow.

I keep seeing comments like this popping up on HN. Do you guys have some funky esoteric configs?

In my case, where I only changed the color scheme and font, the limiting factor when starting alacritty is how fast I can move my fingers to the i3 shortcut. And I'm not running this on some exotic, fast hardware, just your standard crappy corporate HP laptop from a few years ago.

The only time there was a noticeable lag was when my zsh config was borked.

HaoZeke on June 3, 2024| | | [–]

I think the concept of slow is relative here, for a no configuration start (from a fresh install) alacritty is slower by a factor of 4 https://news.ycombinator.com/item?id=40559084

However the absolute times are still probably not noticable unless you often cold-start terminals.

```
                     | Alacritty | Foot | Foot Client |
  Absolute time (ms) |    99.0   | 37.2 | 22.8        |
```

sodality2 on June 3, 2024| | | | [–]

I can say personally that I switched away from alacritty because I would press my key bind and start typing, and it would consistently miss letters because I hadn’t waited for it to fully load. Foot does not.

If it was an app I opened by pressing Super and typing “terminal”, I probably wouldn’t need the speed increase. But the shortcut is easily accessible from home row, so I press it often and quickly.

majoe on June 3, 2024| | | [–]

I switched from konsole to foot, when I upgraded to plasma6 (and therefore to wayland). One of the main reasons was actually startup time. I compared several terminals (konsole, alacritty, kitty, wezterm, foot) and foot had a notably faster startup time than the rest. For me it starts fast enough without a client/server setup, whereas konsole often slightly annoyed me, when I just wanted to execute a single command.

yjftsjthsd-h on June 3, 2024| | [–]

> Right of the bat, it is rather evident that this configuration will spawn two instances of foot, one for each scratchpad.

> Figure 1: Snapshot of memory consumption (from btop), clients take around 10x less memory

By all means use a server/clients approach if it reduces per-process memory, but it's probably not as bad as it looks, because AFAIK the actual executable only gets loaded once and then reused. So each process has its own data in RAM, but the executable/binary only gets loaded the once.

Also, if this is a problem maybe revisit your choice of terminal? It's annoyingly hard to get a total (or more likely I just don't know how to get it), but every number I can seem to find says alacritty is only using <2MB total on my box, so your 27M max on foot looks... weird. Like, I can run a full standalone terminal in the size of your client; I appreciate that it might have features that make it worthwhile, but consider the tradeoffs?

HaoZeke on June 3, 2024| | [–]

btop might be measuring the wrong thing here, but alacritty on my box shows 93M using the same interface. I remember benchmarking foot and alacritty (also kitty) pretty extensively a few years ago, and settled on foot.

Though of course, the memory usage on modern machines is really not a major issue, but the configuration update, along with the tmux session death was annoying..

EDIT: Some timing metrics..

```
  foot -s &
  hyperfine --warmup 8 'alacritty -e true' 'foot -e true' 'footclient -e true'
  Benchmark 1: alacritty -e true
    Time (mean ± σ):      99.0 ms ±  14.2 ms    [User: 58.5 ms, System: 33.4 ms]
    Range (min … max):    82.7 ms … 148.3 ms    32 runs

  Benchmark 2: foot -e true
    Time (mean ± σ):      37.2 ms ±   2.3 ms    [User: 40.3 ms, System: 9.5 ms]
    Range (min … max):    33.8 ms …  43.7 ms    83 runs

  Benchmark 3: footclient -e true
    Time (mean ± σ):      22.8 ms ±   4.3 ms    [User: 0.9 ms, System: 0.8 ms]
    Range (min … max):    18.2 ms …  63.6 ms    133 runs

  Summary
    footclient -e true ran
      1.63 ± 0.32 times faster than foot -e true
      4.35 ± 1.03 times faster than alacritty -e true
```

aumerle on June 3, 2024| | | [–]

timing footclient -e true is not actually measuring what you think its measuring. It's measuring the time it takes to open a socket and write a few bytes to it. Not the time it takes to run true in a new window and then close it. And just FYI both alacritty and kitty have server/client modes too. foot without server client mode does indeed startup faster than any GPU based terminal emulator because GPU based terminal emulators have to probe the GPU card(s) ont he system for their capabilities which is approx 100ms of unavoidable delay until someone convinces the kernel developers to cache this data.

In client server mode all of foot/alacritty/kitty/urxvt will open windows in a few ms.

HaoZeke on June 3, 2024| | | [–]

Good point, however, window creation times aside, the official project org has some benchmarks (https://codeberg.org/dnkl/foot/src/branch/master/doc/benchma...) demonstrating speed-ups in most / all user metrics (a more nuanced discussion is on the performance page: https://codeberg.org/dnkl/foot/wiki/Performance)

akho on June 3, 2024| | | [–]

> it's probably not as bad as it looks, because AFAIK the actual executable only gets loaded once and then reused

The actual foot executable is 427kb. RAM consumption win in the server setup is the shared glyph cache, which is most of the usage at startup.

> alacritty is only using <2MB total on my box

That would be less than the image it’s drawing on screen, the glyph cache, or alacritty’s 11Mb executable. How are you measuring?

MuffinFlavored on June 3, 2024| | [–]

> foot is a lightweight terminal emulator designed for Wayland, focusing on minimal resource usage while maintaining performance.

https://codeberg.org/dnkl/foot

For those out of the loop

paulcarroty on June 3, 2024| | [–]

Still no ligatures support in foot, which is critical in dev environment.

Vegenoid on June 3, 2024| | [–]

Do you mean "critical" literally or hyperbolically? I disable ligatures in any editor/terminal I use, because I find them confusing and want to know what the actual characters in the code are.

stonogo on June 3, 2024| | | [–]

I think there are still dev environments where ligatures in terminals are not so critical. Especially those of devs who do not use in-terminal editors for most of their editing.

maleldil on June 3, 2024| | | [–]

I use and love ligatures, but calling them "critical" is weird. I'll have to admit that they're the reason I don't use alacritty, though.

nurettin on June 3, 2024| | [–]

This is why I run xvfb in systemd instead of using something like xvfb-run which spawns a new virtual display every time you run it.

sed3 on June 3, 2024| | [–]

> Since I often work in strong sunlight, I often want to reconfigure my terminal to use a light or a dark scheme depending on the time of day.

Konsole can switch color theme with simple dbus message.

For the rest, I use tmux sessions and some scripts. When I restart computer, all terminal windows with remote ssh sessions get restored.

I do not need any modifications on server (except tmux or screen package).

Zambyte on June 3, 2024| [–]

I thought the "written by human not AI" badge was kind of cute, then I clicked on it. It seems like people pay for the "right" to put that badge on their page? The author was scammed.

HaoZeke on June 3, 2024| [–]

OP here, I guess things have changed? AFAIK there was no pricing when I set it up... I just put the image with the link, certainly wouldn't pay for it :D

EDIT: So the payment is to have a little space on their own website, which they call a "project page" e.g. https://notbyai.fyi/hi/not-by-ai/

They suggest "linking to it for verification", but it really seems both unnecessary and optional

Zambyte on June 3, 2024| | [–]

I see, thanks for the clarification

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### Looks great, the only gripe I have with Kitty is how slow it is, especially on s... | Hacker News
**URL:** https://news.ycombinator.com/item?id=25940032

```text
Looks great, the only gripe I have with Kitty is how slow it is, especially on s... | Hacker News

| Hacker News new| past| comments| ask| show| jobs| submit | login |
| --- | --- |

alpaca128 on Jan 28, 2021| parent| context| favorite| on: Fix Terminals

Looks great, the only gripe I have with Kitty is how slow it is, especially on startup. I guess mostly because the combination of Python and tons of features has a negative effect in this area. In fact that was the only reason I switched away from it despite its great font ligature support; I use terminals a lot and so the constant delay when opening a new window was a bit much.

However I like those modernised protocols and it would be neat to have widespread support for it.

enriquto on Jan 28, 2021| [–]

This! I would love a "purified" version of kitty which is just an xterm with font ligatures. And no silly features like underlining of links, etc. Also, an option to display bold text by using brighter colors (as God intended).

aumerle on Jan 28, 2021| [–]

kitty startup time was slow because of a bug in GLFW, fixed a while ago. And you can have its startup time be 0 with --single-instance.

alpaca128 on Jan 28, 2021| | [–]

Using the latest kitty release 0.19.3 vs. st, both already loaded:

```
  ~ >=> time st ls

 real   0m0.048s
 user   0m0.041s
 sys    0m0.008s
  ~ >=> time kitty ls

 real   0m0.239s
 user   0m0.173s
 sys    0m0.059s

```

If kitty isn't nicely cached it takes over 500ms on my machine. Using your suggested flag it still takes twice as long.

aumerle on Jan 28, 2021| | | [–]

You need to run kitty -1 to start kitty and leave it running. Then all future kitty -1 invocations will open new windows instantaneously.

aidenn0 on Jan 28, 2021| | | [–]

I use kitty.

"time kitty -1 true" takes about 180ms on my machine. That's more than fast enough for me, but certainly slower than many other terminals.

bsdubernerd on Jan 28, 2021| | [–]

It's still an order of magnitude slower during startup than other terminals such as xterm, rxvt or even mlterm. On my intel laptop I can often see the gl context flashing before becoming the final background color, which is annoying. Requires also way more ram.

kitty is a great terminal, but it's one example of fast not being also lightweight.

aumerle on Jan 28, 2021| | | [–]

I cant reply to your other post, so: you need to run the other kitty instance also with -1. If you do that, you will get the same numbers I got.

bsdubernerd on Jan 29, 2021| | | [–]

I know, I'm actually using kitty regularly.

aumerle on Jan 28, 2021| | | [–]

time kitty -1 false real 0.098 user 0.080 sys 0.017 maxmem 23 MB faults 0

time xterm false real 0.052 user 0.035 sys 0.000 maxmem 9 MB faults 1

Doesnt look like an order of magnitude to me.

bsdubernerd on Jan 28, 2021| | [–]

xterm false 0.06s user 0.01s system 81% cpu 8Mb mem 0.090 total

mlterm -e false 0.08s user 0.02s system 84% cpu 13Mb mem 0.125 total

kitty -1 false 0.22s user 0.05s system 93% cpu 78Mb mem 0.290 total

(and yes, there's a kitty instance running already..)

| Guidelines| FAQ| Lists| API| Security| Legal| Apply to YC| Contact (hn@ycombinator.com) Search: |
| --- |
```

---

### The latencies are different, and kitty is slower at this because the author does... | Hacker News
**URL:** https://news.ycombinator.com/item?id=35808763

```text
The latencies are different, and kitty is slower at this because the author does... | Hacker News

The latencies are different, and kitty is slower at this because the author doesn't care about huge output[0]:

> Some people have asked why kitty does not perform better than terminal XXX in the test of sinking large amounts of data, such as catting a large text file. The answer is because this is not a goal for kitty. kitty deliberately throttles input parsing and output rendering to minimize resource usage while still being able to sink output faster than any real world program can produce it. Reducing CPU usage, and hence battery drain while achieving instant response times and smooth scrolling to a human eye is a far more important goal.

I use 'yes | head -n 1000000' for a throughput test, and kitty is about 5x faster than xterm and 1/3 the speed of alacritty (zutty does not appear to be packaged in my OS). It's rather unusual to see something that is held up by terminal rendering (sbcl's build process used to be, and they recommended using xterm for faster builds, so 5x faster than xterm is probably "good enough" there).

This sounds backwards from both an energy perspective and human factors perspective. I don't understand the throughput vs. smooth scrolling tradeoff though.
```

---

### I wonder how Kitty would do on these benchmarks. Kitty is a different beast to A... | Hacker News
**URL:** https://news.ycombinator.com/item?id=39967219

```text
I wonder how Kitty would do on these benchmarks. Kitty is a different beast to A... | Hacker News|**Hacker News**new|past|comments|ask|show|jobs|submit|login|
|
|
|
sevgon April 8, 2024|parent|context|favorite| on:How much faster are the Gnome 46 terminals?
I wonder how Kitty would do on these benchmarks.
Kitty is a different beast to Alacritty and has tonnes of features (many of which I'm grateful for), but I wonder what the performance cost is.
|
|
|
aumerleon April 8, 2024|next[–]
There is no performance cost, there is a performance gain:https://sw.kovidgoyal.net/kitty/performance/#throughput
|
|
|
|
abhinavkon April 8, 2024|parent|next[–]
Kitty was slower than alacritty and foot as per author's earlier input latency tests.
https://mastodon.online/@YaLTeR/110837121102628111
|
|
|
|
aumerleon April 8, 2024|root|parent|next[–]
That's because kitty's default settings introduce a few ms of latency deliberately to save energy, see details at:https://sw.kovidgoyal.net/kitty/performance/#keyboard-to-scr...
If you want to do a fair comparison to alacritty you need to set those to the recommended values for best latency.
|
|
|
|
reyqnon April 8, 2024|root|parent|next[–]
Still slower than alacritty according tohttps://beuke.org/terminal-latency/
Also not really cross-platform, contrary to what's indicated in the first word of its github description, and the owner is kind of an ass about ithttps://github.com/kovidgoyal/kitty/issues/6481.
|
|
|
|
josefxon April 8, 2024|root|parent|next[–]
Cross platform does not automatically mean something supports all platforms, nothing does.
|
|
|
|
PurpleRamenon April 8, 2024|root|parent|next[–]
But it should support at least more than one platform. And it's disputable what exactly one considers as a platform, or just a flavor of some platform.
|
|
|
|
lupusrealon April 8, 2024|root|parent|next[–]
It does support more than one platform. It supports linux and MacOS, which is two, plus probably half a dozen more flavors of BSD.
|
|
|
|
PurpleRamenon April 8, 2024|root|parent|next[–]
As said, it depends on the definition of platform for this case. All I see is support of a bunch of flavors of one platform, namely POSIX, unixoids, or how you want to call it. Yes, they are different desktop-platforms, but the purpose of this software is still limited to one specific environment. Or to give a different perspective, nobody would call it cross-platform, just because it can run with Gnome and KDE, under X11 and Wayland.
And I'm curious how much adaption happens for each OS really. Are there specific changes for MacOS and BSD, outside of some paths for configurations?
|
|
|
|
dpassenson April 8, 2024|root|parent|next[–]
The entire point of POSIX is that, if you only use what it defines, your program automatically becomes cross-platform, because it will run on several Unices, as well as other systems (like Haiku).
|
|
|
|
pasc1878on April 8, 2024|root|parent|prev|next[–]
MacOS will have to be different as the GUI layer is not X11 or anything like it.
|
|
|
|
PurpleRamenon April 8, 2024|root|parent|next[–]
Wayland is also not X11.
Just curious, but is it really so hard for people here to think outside the box?
|
|
|
|
dpassenson April 8, 2024|root|parent|next[–]
To me, it seems like the people thinking inside the box are those that claim that cross-platform necessarily implies it runs on Windows.
|
|
|
|
lupusrealon April 8, 2024|root|parent|prev|next[–]
It's probably fair to say that an application with native Wayland and X11 support is multiplatform. I can understand somebody disputing that, but certainly Linux and MacOS are different platforms. They don't even share executable formats.
|
|
|
|
reyqnon April 8, 2024|root|parent|prev|next[–]
The heavy lifting is done by glfw though.
|
|
|
|
jraphon April 8, 2024|root|parent|prev|next[–]
> Also not really cross-platform [...]
How is this relevant to this conversation?
The author replied with the same effort as the person who reported the issue. You kinda need to do this as a maintainer if you don't want to drawn under low quality reports and burn all your energy. I'm sure lucasjinreal would have gotten a kinder answer if they took time to phrase their issue ("demand", at this point, also misguided) nicely.
|
|
|
|
reyqnon April 8, 2024|root|parent|next[–]
It's not really, I just remembered wanting to try out this terminal emulator and being quite surprised that something actively advertised as cross-platform didn't support Windows.
I agree that the person posting the issue wasn't really doing it in a diplomatic way, but in the end, the result is the same. I think it's disingenuous to actively advertise something as cross-platform, without even specifying which platforms are actually supported (even if yes, technically it's cross-platform)
|
|
|
|
Karellenon April 8, 2024|root|parent|next[–]
> without even specifying which platforms are actually supported
The*first line*of the README (ok, second line if you include the title) is "See the kitty website" with a link, and on the site the top menu has a "cross platform" entry which then lists "Linux, MacOS, Various BSDs".
It seems like a stretch to classify that as disingenuous.
|
|
|
|
reyqnon April 8, 2024|root|parent|next[–]
So I have to click twice, change domains once in order to get this information.
It's actually easier to just check the releases for prebuilt windows binaries. I think that's telling.
|
|
|
|
Karellenon April 8, 2024|root|parent|next[–]
> So I have to click twice, change domains
If you start from the github source code repo, instead of starting from the official website.
I guess.
If you're determined to be disappointed, I suppose you'll find a way. Whatever.
|
|
|
|
pxcon April 8, 2024|root|parent|prev|next[–]
Anything that supports more than one platform is cross-platform. The world doesn't revolve around Windows.
|
|
|
|
aumerleon April 8, 2024|root|parent|prev|next[–]
And kitty is much faster according to this:https://github.com/kovidgoyal/kitty/issues/2701#issuecomment...
Also typometer based measurements also on Linux. Shrug.
|
|
|
|
reyqnon April 8, 2024|root|parent|next[–]
This was 2 and a half year ago, maybe alacritty improved since then.
|
|
|
|
aumerleon April 8, 2024|root|parent|next[–]
Maybe, on the other hand: the link you posted was to a benchmark using kitty 0.31, since then it had an all new escape code parser using SIMD vector CPU instructions that sped it up by 2x.https://sw.kovidgoyal.net/kitty/changelog/#cheetah-speed
|
|
|
|
reyqnon April 8, 2024|root|parent|next[–]
I do think this wasn't excluded by the benchmarks from the link I posted
Edit: actually it was, cheetah seems to come with 0.33, not 0.31, and benchmarks were done in 0.31. It would be interesting to run them with 0.33.
|
|
|
|
alpaca128on April 8, 2024|parent|prev|next[–]
That's only throughput, but on latency it's significantly slower than alacritty, xterm, st etc according to all measurements I've seen.
|
|
|
|
cyber24on April 8, 2024|prev|next[–]
The same person shared very similar benchmarks that include kitty on mastodon:https://mastodon.online/@YaLTeR/110842581333774175
They are a bit older but might still give a general idea.
|
|
|
|
ramon156on April 8, 2024|prev[–]
I never understood why people want a bunch of features on their terminal. I just want a terminal that doesn't get in the way of my tools. Alacritty is great at that
|
|
|
|
Join us forAI Startup Schoolthis June 16-17 in San Francisco!
Guidelines|FAQ|Lists|API|Security|Legal|Apply to YC|Contact (hn@ycombinator.com)
Search:|
```

---

### How does performance compare to st? Has any one tested both? | Hacker News
**URL:** https://news.ycombinator.com/item?id=24643685

```text
How does performance compare to st? Has any one tested both? | Hacker News

How does performance compare to st? Has any one tested both?

I haven't used a considerable amount of time using st (I think for a total of 2 days on a VM?) I liked st just fine but I found the day-to-day performance of kitty really solid.

It feels like kitty takes _slightly_ longer to start up but it's still a tiny amount of time.

There's also the different configuration options, kitty has a config file but st (if memory serves) needs to be recompiled for changes.

I've found that initially kitty can have trouble rendering fonts with correct spacing but that takes a couple of minutes to tweak to your liking. And I think the colour configurations are a little more complex? I haven't had to change the config for a while though.

The GPU acceleration does make stdout much faster if it's unbuffered (in my experience) and on a 144hz monitor it looks so much smoother.

Hopefully that's enough of a comparison? Sorry I couldn't give more feedback, as mentioned I've only used st for a short time.

> It feels like kitty takes _slightly_ longer to start up but it's still a tiny amount of time.

For me the difference was large enough to switch to st. Kitty's startup takes 5-10 times as long and it's very noticable for me. As I use terminals a lot this meant a delay every time I opened an instance.

But this is a subjective thing of course. I have all the features I need with st and use a terminal multiplexer for the rest.

You can also use kitty -1 to use a single instance of kitty although the startup time is already so small I doubt you could tell the difference without measuring

I use both, but don't really feel like there is a useful comparison.

My lightly patched st /feels/ better IME, but it doesn't have anywhere near the same featureset. kitty has its fancier font support and cool kittens which make the comparison very uneven.

I limit my kitty use to a single long running instance as my vim terminal, taking advantage of its far better rendering for pretty symbols and inline images via the icat kitten. For everything else I find st/urxvt far more useful, in spite of the occasional rendering errors and font selection problems. Even going so far as to fiddle with sxiv's Xembed support to weakly imitate kitty's icat from time to time.

While this doesn't have test for everything you might care about, https://github.com/alacritty/vtebench could help you answer this question on your own machine.

Simply run the tool within the terminal under test. It's quite easy to use.

I've used both. I have no figures but kitty feels at least as fast as st with infinitely more features and a proper configuration system.
```

---

### Using the latest kitty release 0.19.3 vs. st, both already loaded: ~ >=> time st... | Hacker News
**URL:** https://news.ycombinator.com/item?id=25940617

```text
Using the latest kitty release 0.19.3 vs. st, both already loaded: ~ >=> time st... | Hacker News

Using the latest kitty release 0.19.3 vs. st, both already loaded:

```
  ~ >=> time st ls

 real   0m0.048s
 user   0m0.041s
 sys    0m0.008s
  ~ >=> time kitty ls

 real   0m0.239s
 user   0m0.173s
 sys    0m0.059s

```

 If kitty isn't nicely cached it takes over 500ms on my machine. Using your suggested flag it still takes twice as long.

aumerle on Jan 28, 2021 [–]

You need to run kitty -1 to start kitty and leave it running. Then all future kitty -1 invocations will open new windows instantaneously.

aidenn0 on Jan 28, 2021 | parent [–]

I use kitty.

"time kitty -1 true" takes about 180ms on my machine. That's more than fast enough for me, but certainly slower than many other terminals.
```

---


## 8. UNTAGGED MISCELLANEOUS (Требует ручного разбора)

### Love this. My https://llm.datasette.io/ CLI tool supports plugins, and people we... | Hacker News
**URL:** https://news.ycombinator.com/item?id=45467095

```text
Love this. My https://llm.datasette.io/ CLI tool supports plugins, and people we... | Hacker News

simonw 8 months ago | parent | context | favorite | on: PEP 810 – Explicit lazy imports

Love this. My https://llm.datasette.io/ CLI tool supports plugins, and people were complaining about really slow start times even for commands like "llm --help" - it turned out there were popular plugins that did things like import pytorch at the base level, so the entire startup was blocked on heavy imports.

I ended up adding a note to the plugin author docs suggesting lazy loading inside of functions - https://llm.datasette.io/en/stable/plugins/advanced-model-pl... - but having a core Python language feature for this would be really nice.

zahlman 8 months ago | next [–]

You can implement this from your tool today: https://news.ycombinator.com/item?id=45467489

Note that this is global to the entire process, so for example if you make an import of Numpy lazy this way, then so are the imports of all the sub-modules. Meaning that large parts of Numpy might not be imported at all if they aren't needed, but pauses for importing individual modules might be distributed unpredictably across the runtime.

Edit: from further experimentation, it appears that if the source does something like `import foo.bar.baz` then `foo` and `foo.bar` will still be eagerly loaded, and only `foo.bar.baz` itself is deferred. This might be part of what the PEP meant by "mostly". But it might also be possible to improve my implementation to fix that.

dahart 8 months ago | parent | next [–]

Note the PEP does have a FAQ entry that mentions reasons they believe this proposed solution might be preferable to LazyLoader

https://pep-previews--4622.org.readthedocs.build/pep-0810/#f...

Q: Why not use importlib.util.LazyLoader instead?

A: LazyLoader has significant limitations:

Requires verbose setup code for each lazy import.

Has ongoing performance overhead on every attribute access.

Doesn’t work well with from ... import statements.

Less clear and standard than dedicated syntax.

zahlman 8 months ago | root | parent | next [–]

Thanks for pointing it out!

> Has ongoing performance overhead on every attribute access.

I would have expected so, but in my testing it seems like the lazy load does some kind of magic to replace the proxy with the real thing. I haven't properly dug into it, though. It appears this point is removed in the live version (https://peps.python.org/pep-0810).

> Doesn’t work well with from ... import statements.

Hmm. The PEP doesn't seem to explain how reification works in this case. Per the above it's a solved problem for modules; I guess for the from-imports it could be made to work essentially the same way. Presumably this involves the proxy holding a reference to the namespace where the import occurred. That probably has a lot to do with restricting the syntax to top level. (Which is the opposite of how we've seen soft keywords used before!)

> Requires verbose setup code for each lazy import.

> Less clear and standard than dedicated syntax.

If you want to use it in a fine-grained way, then sure.

wslh 8 months ago | parent | prev | next [–]

Is it another potential solution (until PEP 810 is accepted) to override the NameError exception, decide if it was triggered by an unloaded package from a list, and then running again that line of code? I understand the inefficiency of this solution (e.g. the same line could trigger NameError several times and you need to run it again until all modules are loaded) but this is a good brainstorming thread.

zahlman 8 months ago | root | parent | next [–]

That sounds very unpleasant. However nicely you wrapped it up, you'd still be referring to the code for that process everywhere that the NameError could occur.

peterfirefly 8 months ago | prev | next [–]

Parse the command line and do things like "--help" without doing the imports.

Only do imports when you know you need them -- or as an easy approximation, only if the easy command line options have been handled and there's still something to do.

mr_mitm 8 months ago | parent | next [–]

In the llm project, plugins can modify the command line arguments, so it's not that simple.

simonw 8 months ago | root | parent | next [–]

Yea, that's the core problem here: plugins can add new CLI subcommands, which means they all need to be loaded on startup.

https://llm.datasette.io/en/stable/plugins/plugin-hooks.html...

zahlman 8 months ago | root | parent | next [–]

Just FWIW, a trick that I'm planning to use for PAPER: first I make separate actual commands — `paper-foo`, `paper-bar` etc. that are each implemented as separate top-level scripts that can import only what they need. Later, the implementation of `paper foo` has the main `paper` script dynamically look up `paper-foo`. (Even a `subprocess.call` would work there but I'd like to avoid that overhead)

Could you cache the help doc after first full loaded run and only regenerate when new plugins are added / updated?

simonw 8 months ago | root | parent | next [–]

It's not just help - the plugins need to be imported so the root level CLI tool knows what to do if you type "llm subcommand ..." where that subcommand is defined by a plugin.

Inufu 8 months ago | root | parent | next [–]

In that case the CLI only needs to import the plugin that defined that sub command, not all plugins?

simonw 8 months ago | root | parent | next [–]

It doesn't know which plugin defines a subcommand until it imports the plugin's module.

I'm happy with the solution I have now, which is to encourage plugin authors not to import PyTorch or other heavy dependencies at the root level of their plugin code.

peterfirefly 8 months ago | root | parent | next [–]

> It doesn't know which plugin defines a subcommand until it imports the plugin's module.

That might be considered a design mistake -- one that should be easy to migrate away from.

You won't need to do anything, of course, if the lazy import becomes available on common Python installs some day in the future. That might take years, though.

whatevaa 8 months ago | parent | prev | next [–]

Or require plugins to be competently written.

Bad performing third party plugins are user error.

stavros 8 months ago | parent | prev | next [–]

Well yes, or you can just use the `lazy` keyword, when it makes it into core.

loloquwowndueo 8 months ago | root | parent | next [–]

You can “just” use a feature which does not exist yet? How is that something you “just” do?

Y_Y 8 months ago | root | parent | next [–]

```
  lazy from __future__ import __lazy_import__
```

zahlman 8 months ago | root | parent | next [–]

I think Guido's time machine will need some serious overclocking to handle that one!

Neywiny 8 months ago | prev | next [–]

I think really the problem is that packages like pytorch take so long to import. In my work I've tried a few packages (not AI stuff) that do a lot of work on import. It's actually quite detrimental because I have to setup environment variables to pass things that should be arguments of a setup function in. All things considered a python module shouldn't take any noticeable time to import

zvr 8 months ago | prev | next [–]

It's not only in the case of plugins.

If a tool has different capabilities that use different imports, why load all of them if only a subset is required?

As a simple example, a tool that can generate output in various formats (e.g., json, csv, xml, ...) should only import the appropriate modules to handle the output format after having determined which ones will be used in this invocations.
```

---

### Woop! My timerfd change is finally out in the wild! This will ...
**URL:** https://news.ycombinator.com/item?id=37841782

```text
Woop! My timerfd change is finally out in the wild! This will make it so that (o... | Hacker News

WJW on Oct 11, 2023 | parent | context | favorite | on: GHC 9.8.1

Woop! My timerfd change is finally out in the wild!

This will make it so that (on systems with timerfd) the runtime will no longer have to wait for the next runtime tick before exiting. This saves on average 5 ms per program run, and up to 10 ms for programs with a very short runtime. Not much for server programs with an expected lifetime of days/weeks, but potentially quite nice for CLI programs like hledger or for programs that invoke many other Haskell programs.

I accidentally discovered this when trying to optimize an Advent of Code problem and couldn't get it below 10 ms no matter what I tried. Eventually I discovered that "hello world" also took 10 ms so I assumed it was just runtime startup costs. Decided to look anyway and found out it was actually runtime shutdown costs, where the runtime would `join` the rts "ticker" thread. The ticker thread would only check for a shutdown flag once every loop, so 10 ms with the default settings. Now it can be shut down immediately, which makes small programs much faster.

pja on Oct 11, 2023 [–]

Oh wow. I’ll have to recompile some of my old AoC Code to see how fast it really runs now!

Like you I had assumed this was simply runtime startup / teardown overhead.
```

---

### I’m glad that works for you but that sounds like a horrible solution to me. Mayb... | Hacker News
**URL:** https://news.ycombinator.com/item?id=28934101

```text
I’m glad that works for you but that sounds like a horrible solution to me. Mayb... | Hacker News

I’m glad that works for you but that sounds like a horrible solution to me. Maybe better than Bash but magic named files are probably my least favourite feature in scripting languages.

Don't think of it as magic, but as convention. Where do you put your function definitions? In the folder named "functions". There are only a handful of such things to learn.

> Where do you put your function definitions?

Inside ‘function’ blocks, like the language syntax defines for any other type of function. I can then throw those functions into any file I chose.

Having special functions inside special files just creates annoying special cases I need to look up.

In fish, you put the functions inside function blocks. There's nothing at all magical about that. However, if you write "function foo" inside a file named "foo.fish", then type the command "foo" at the shell prompt, then fish will look for a file named "foo.fish" and then execute the function "foo" defined inside it. That's its autoload mechanism.

That's the only remotely magical thing added here: by convention, an autoload function named "foo" is defined in ~/.config/fish/functions/foo.fish.

Your .bashrc, .zshrc, .profile, etc. files are also special. All that's going on is that there is folder where you can leave functions to be included in the main namespace, I don't see the big difference.

The difference as I understand it is your Fish equivalent of a $PS1 (and other Fish shell behaviours) have to be defined via that path. If I understand it correctly, it sounds a lot like git hooks but at a global scale rather than per repo.

Now I’ve got nothing against git hooks nor Fish per se, I just don’t see this particular model for defining behaviour to be convenient (eg what if you want to quickly change the prompt of a session without affecting other sessions?)

There might be more detail I’m missing and if that’s the case I apologise. But from what I’ve read thus far I’m not sold. It might appeal to others and good for them.

How would you normally do it? Because you can still put redefinitions of all the standard functions into a single file and load them with `.` as you would with other shells.

There's also this package, which the author admits only allows "slight" customization, to implement sessions: https://github.com/farzadghanei/fishion

Well I’m not suggesting the following is a better alt shell, but in murex you have something that’s a little bit akin to a Windows Registry in that all of the shell settings are navigable through a builtin called ‘config’

You can set prompt functions with that; strings, ints and Booleans too. And ‘config’ comes with descriptions for each configurable thing, choices of options in many cases, and an easy way to default back to shell defaults too. So it’s dead easy to play around configuring whatever you want (you never need to leave the shell to look up an option).

The shell has its own problems though but it’s an interesting alternative take for grouping shell config.

>The difference as I understand it is your Fish equivalent of a $PS1 (and other Fish shell behaviours) have to be defined via that path.

They don't. You have to define the function somehow, but fish doesn't care about how that happens. It's just that if it's not defined yet it'll try to load it from the file.

If you want, you can just do it all in config.fish, like you'd do it all in .bashrc for bash.

>what if you want to quickly change the prompt of a session without affecting other sessions?

Then you can redefine the function, just like you could switch the value of $PS1.

Ok. That sounds a lot more sane then. Thank you for the clarification.

You can literally still do it the way you want, there's just a convention that `fish` uses to autoload so you don't have to if you don't want to.

It's as simple and seductive as Ruby on Rails was 20 years ago.

I was going to mount a defense of fish about how it doesn't provide the same mechanisms or provide the same incentives that had people contorting Ruby into the most convoluted forms on their way to spit out HTML or JSON from an HTTP request, but then I found that the thing has a `fish_command_not_found` that you can overload as in Ruby.

So yeah you could make crazy stuff like Rail's routing and rendering DSLs that interpreted method names as programs.

Bash and zsh have basically the same thing.

It's meant to give you a nice error message like

"foo is missing. You can install it with 'apt install foo123'"

See:

- https://zsh.sourceforge.io/Doc/Release/Command-Execution.htm... for zsh

- https://www.gnu.org/software/bash/manual/bash.html#Command-S... for bash

You could make it run arbitrary things, but then you're quite clearly misusing it and e.g. there's no way to make it return a different status, fish will still view the command as failed.

Setting a specific path as an “autoload” path to load shell functions is in bash and zsh too?

Yeah, but there aren’t magic function paths that you need to do basic things like setting the prompt.

Don’t get me wrong, I think the PS1 variable sucks. But I’m not convinced Fish’s solution is much better.

Okay so I think I understand your objection a bit more. So fish only wants you to define a function called fish_prompt in order to customize the prompt. That function can be defined however you want. It can be in fish’s equivalent of .bashrc (~/.config/fish/config.fish). Putting it in ~/.config/fish/functions/fish_prompt.fish is just leveraging more tooling around shell function autoloading and sane defaults.

You can achieve PS1-like functionality “simply” by placing this bit of code somewhere in your startup:

```
  function fish_prompt
      set -l prompt_symbol '$'
      fish_is_root_user; and set prompt_symbol '#'

      echo -s $hostname (set_color blue) (prompt_pwd) \
      (set_color yellow) $prompt_symbol (set_color normal)
  end

```

It’s very verbose but it runs as fast as both bash’s PS1 and zsh’s PROMPT and is much easier for someone new to fussing with prompts to comprehend.

Even as someone who doesn’t use fish day to day, I think fish’s prompt customization is much more approachable. If I had a powerline prompt I wanted to tweak, I’d know to start with `functions fish_prompt` to print out the current contents of the function and have the complete code to how the prompt is built. zsh requires a lot more reading and understanding of the prompt system before you can dig into how exactly it all works. IIRC, most dynamic bash prompts have similar issues. PS1 is just interpolated globals and color codes, creating a disconnect between the prompt variable and the shell functions that update it.
```

---


