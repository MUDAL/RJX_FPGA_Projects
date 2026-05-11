# LVGL on DE1-SoC: HPS-First Project Guide

**Goal:** run an LVGL-based GUI on the DE1-SoC, using the ARM HPS for software and the FPGA fabric for VGA scanout.

**Recommended first architecture:**

```text
microSD boot image
   │
   ▼
HPS / ARM Cortex-A9 / Linux
   ├─ LVGL application
   ├─ input through Linux evdev: USB mouse, keyboard, touch, etc.
   ├─ control registers through lightweight HPS→FPGA bridge
   └─ framebuffer writes through HPS→FPGA bridge or a mapped framebuffer window
          │
          ▼
FPGA fabric
   ├─ register block
   ├─ framebuffer storage or framebuffer read path
   ├─ optional 2× scaler
   ├─ optional double buffering / VSYNC swap logic
   └─ VGA timing + RGB output
          │
          ▼
       VGA monitor
```

---

## 1. Big Picture

The DE1-SoC is a great board for this project because it combines:

- an ARM HPS, useful for Linux, USB input, C/C++ software, and LVGL;
- FPGA fabric, useful for video timing, scanout, memory-mapped peripherals, and custom acceleration;
- VGA output on the FPGA side;
- HPS DDR3 memory and FPGA-side memory resources;
- HPS-to-FPGA bridges for communication between Linux software and custom FPGA hardware.

The project should be built in layers. Do **not** start by trying to make the final polished Linux display driver. Start by proving each part separately:

1. FPGA can generate VGA.
2. FPGA can read pixels from a framebuffer.
3. HPS can write test pixels into that framebuffer.
4. LVGL can call a custom `flush_cb` that copies rendered rectangles into the framebuffer.
5. Input works through Linux.
6. Then improve buffering, performance, and polish.

The strongest first route is **HPS-first**, not Nios V-first. Nios V is still a very cool later extension, but HPS-first gets you Linux, USB input, easier builds, easier debugging, and a faster path to seeing a real GUI.

---

## 2. Recommended Starting Design Choices

| Area | Recommended first choice | Why |
|---|---|---|
| CPU | HPS ARM Cortex-A9 running Linux | Fastest path to LVGL + USB input |
| Display output | FPGA VGA generator | DE1-SoC VGA is FPGA-facing |
| LVGL integration | Custom LVGL `flush_cb` in user space | Avoids writing a kernel display driver at first |
| Input | Linux `evdev` | USB mouse/keyboard works naturally under Linux |
| Logical resolution | `320×240` | Small framebuffer, easier bandwidth, faster redraws |
| Physical output | `640×480 @ 60 Hz` VGA | Standard, monitor-friendly starting mode |
| Scaling | FPGA 2× nearest-neighbor scaler | Makes 320×240 fill 640×480 |
| Pixel format | RGB565, 16 bits per pixel | Small, simple, common LVGL format |
| First framebuffer location | FPGA SDRAM, if convenient | Simple FPGA scanout path and enough room |
| First control interface | Lightweight HPS-to-FPGA bridge | Good for registers, status, and small commands |
| Later display interface | `/dev/fb0` or DRM/KMS | More polished, but not necessary for MVP |

---

## 3. What We Already Decided

### Main project path

Use the **HPS** first:

- boot Linux from microSD;
- run LVGL as a normal Linux C/C++ program;
- use a custom display backend that writes into an FPGA-visible framebuffer;
- use FPGA logic to continuously read the framebuffer and drive VGA.

### Optional later path

Port to **Nios V** later:

- Nios V can be used as a soft processor in supported Intel/Altera FPGA families, including Cyclone V according to Altera’s Nios V developer documentation;
- Nios V would be an excellent advanced version after the FPGA display hardware is already proven;
- the Nios V route will likely require more bare-metal/RTOS work: tick timer, input drivers, memory handling, and LVGL porting details.

### Why not start with Nios V?

Starting with Nios V is possible, but it makes several things harder at the same time:

- no normal Linux user-space development loop;
- less convenient USB input;
- more bare-metal setup;
- more manual timing and driver work;
- more debugging inside FPGA-generated systems.

The HPS-first route lets you separate the project into manageable pieces.

---

## 4. Core Terms

| Term | Meaning in this project |
|---|---|
| HPS | Hard Processor System: ARM Cortex-A9 processor subsystem inside the Cyclone V SoC |
| FPGA fabric | Programmable logic side of the Cyclone V SoC |
| LVGL | Lightweight GUI library that renders widgets into draw buffers |
| framebuffer | Memory region containing pixel values for the screen |
| scanout | FPGA process that reads framebuffer pixels in display order and sends them to VGA |
| VGA timing | Horizontal/vertical counters, sync pulses, blanking periods, and active video region |
| `flush_cb` | LVGL callback that receives rendered pixels and sends/copies them to the display |
| RGB565 | 16-bit pixel format: 5 red bits, 6 green bits, 5 blue bits |
| VSYNC | Vertical synchronization pulse; useful timing point for clean buffer swaps |
| HPS-to-FPGA bridge | AXI bridge from ARM/HPS side into FPGA address space |
| Lightweight HPS-to-FPGA bridge | Smaller bridge commonly used for control/status registers |
| FPGA-to-HPS / FPGA-to-SDRAM | Path that can let FPGA logic access HPS-side memory, useful for advanced designs |
| UIO | Linux Userspace I/O framework; cleaner than raw `/dev/mem` for mapping hardware registers |

---

## 5. Architecture Options

### Option A — Best MVP: framebuffer in FPGA-side memory

```text
HPS LVGL app
   │
   │ writes rectangles
   ▼
HPS→FPGA bridge
   │
   ▼
FPGA SDRAM or framebuffer RAM
   │
   ▼
VGA scanout logic
   │
   ▼
VGA monitor
```

Use this first if possible.

Advantages:

- simple conceptual model;
- FPGA owns the display timing and framebuffer read path;
- HPS just writes pixels;
- easier to test with simple rectangle-writing programs before LVGL.

Disadvantages:

- HPS-to-FPGA writes may be slower than writing to HPS DDR;
- you need a memory controller or framebuffer RAM on the FPGA side;
- arbitration between HPS writes and VGA reads matters.

This is still the recommended MVP because it is easier to reason about.

### Option B — Advanced: framebuffer in HPS DDR3

```text
HPS LVGL app
   │
   │ writes into HPS DDR framebuffer
   ▼
HPS DDR3
   ▲
   │ FPGA reads through FPGA-to-HPS SDRAM interface
   │
FPGA VGA scanout logic
   │
   ▼
VGA monitor
```

Advantages:

- huge framebuffer space;
- HPS writes to its own DDR efficiently;
- better for larger resolutions and full double/triple buffering.

Disadvantages:

- more complicated memory sharing;
- cache coherency becomes important;
- FPGA-to-HPS SDRAM bridge setup is more advanced;
- Linux may need reserved memory or a driver to make this robust.

Use this after Option A works.

### Option C — Polished Linux route: framebuffer or DRM driver

```text
LVGL fbdev/DRM backend
   │
   ▼
Linux framebuffer or DRM/KMS driver
   │
   ▼
custom FPGA video hardware
   │
   ▼
VGA
```

Advantages:

- more standard Linux graphics stack;
- LVGL can use its Linux `fbdev` or DRM backend;
- easier to reuse other Linux tools later.

Disadvantages:

- requires kernel/device-tree/driver work;
- takes longer before the first pixels appear.

Do **not** start here unless you already know Linux driver development.

---

## 6. Minimum Viable Product Definition

Your first real success should be:

- DE1-SoC boots Linux on the HPS;
- FPGA VGA output displays stable `640×480 @ 60 Hz`;
- FPGA scales a `320×240` RGB565 framebuffer to the VGA screen;
- HPS user-space program can write rectangles into the framebuffer;
- LVGL demo or a simple LVGL screen appears on the VGA monitor;
- USB mouse pointer or simple input events work through Linux evdev.

Do not add animations, fancy themes, touchscreens, DMA acceleration, or kernel drivers before this MVP works.

---

## 7. Milestone Roadmap

## Milestone 0 — Project Setup and Research

### Goal

Get tools, docs, repo structure, and board access ready.

### Tasks

- Install Quartus Prime version that supports your DE1-SoC/Cyclone V workflow.
- Install ARM cross-compiler or confirm you can compile directly on the HPS.
- Prepare a Linux microSD image for the DE1-SoC.
- Confirm UART serial console works.
- Confirm Ethernet or USB file transfer works.
- Create a Git repo.
- Save all board docs and links in `docs/references.md`.

### Suggested repo layout

```text
de1soc-lvgl/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── memory-map.md
│   ├── bringup-log.md
│   └── references.md
├── hw/
│   ├── rtl/
│   │   ├── vga_timing.sv
│   │   ├── rgb565_to_vga.sv
│   │   ├── fb_reader.sv
│   │   └── de1soc_lvgl_top.sv
│   ├── platform_designer/
│   ├── constraints/
│   └── sim/
├── sw/
│   ├── hps_pixel_test/
│   ├── hps_lvgl_app/
│   └── common/
└── scripts/
    ├── build_hw.sh
    ├── build_sw.sh
    └── copy_to_board.sh
```

### Checkpoint

You can boot the board, log in, compile/run a hello-world program, and program the FPGA.

### Hints

- Keep a `bringup-log.md` file. Record every command, error, fix, and working version.
- Save exact Quartus project settings and pin assignments in the repo.
- Commit known-good hardware even if it is just blinking LEDs.

---

## Milestone 1 — HPS Linux Sanity Check

### Goal

Make sure Linux on the HPS is usable before adding custom FPGA video hardware.

### Tasks

- Boot Linux from microSD.
- Verify serial console.
- Verify the board has a working shell.
- Verify networking if available:

```sh
ip addr
ping 8.8.8.8
```

- Check CPU and kernel:

```sh
uname -a
cat /proc/cpuinfo
```

- Check input devices after plugging in a USB mouse/keyboard:

```sh
cat /proc/bus/input/devices
ls -l /dev/input/
```

- If available, use `evtest` to inspect events:

```sh
evtest
```

### Checkpoint

You can copy a compiled program onto the board and run it. USB input devices appear under `/dev/input/event*`.

### Hints

- If networking is annoying, use serial + microSD file copy first.
- If `evtest` is missing, you can still inspect `/proc/bus/input/devices`.
- Record which `/dev/input/eventX` belongs to the mouse.

---

## Milestone 2 — HPS-to-FPGA Register Test

### Goal

Prove that the HPS can control simple FPGA registers.

### Hardware

Create a tiny FPGA register block:

- register 0: ID/version;
- register 1: LED control;
- register 2: scratch register;
- register 3: status/counter.

Example register map:

| Offset | Name | Access | Purpose |
|---:|---|---|---|
| `0x00` | `REG_ID` | RO | Magic value, for example `0x4C56474C` = `LVGL` |
| `0x04` | `REG_CONTROL` | RW | Enable bits, test bits |
| `0x08` | `REG_STATUS` | RO | Hardware status |
| `0x0C` | `REG_SCRATCH` | RW | Write/readback test |
| `0x10` | `REG_FRAME_COUNT` | RO | Increments once per frame later |

### Software

Write a tiny Linux C program that maps the register address and reads/writes values.

At the earliest prototype stage, many DE1-SoC examples use `/dev/mem`. For a cleaner project, move to UIO later.

Pseudo-code shape:

```c
int fd = open("/dev/mem", O_RDWR | O_SYNC);
void *map = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, PHYS_BASE);
volatile uint32_t *regs = (volatile uint32_t *)map;

printf("ID = 0x%08x\n", regs[0]);
regs[3] = 0x12345678;
printf("scratch = 0x%08x\n", regs[3]);
```

### Checkpoint

A Linux program can:

- read a known ID register;
- write a scratch register and read it back;
- toggle LEDs or another simple FPGA output.

### Hints

- If every read returns `0xFFFFFFFF` or bus errors, suspect bridge/address setup.
- If the value changes but not the LEDs, suspect your register logic or top-level pin connections.
- Do not trust addresses copied from a different project. Use your Platform Designer address map and generated headers.

---

## Milestone 3 — FPGA VGA Timing Only

### Goal

Generate a stable VGA test pattern from FPGA logic only.

### Starting mode

Use `640×480 @ 60 Hz`.

Common timing values:

| Item | Value |
|---|---:|
| Pixel clock | `25.175 MHz` ideal; `25.0 MHz` often accepted by monitors |
| Horizontal active | `640` pixels |
| Horizontal front porch | `16` pixels |
| Horizontal sync | `96` pixels |
| Horizontal back porch | `48` pixels |
| Horizontal total | `800` pixels |
| Vertical active | `480` lines |
| Vertical front porch | `10` lines |
| Vertical sync | `2` lines |
| Vertical back porch | `33` lines |
| Vertical total | `525` lines |
| Sync polarity | usually negative for 640×480 VGA |

### Suggested test patterns

Implement these in order:

1. solid red;
2. solid green;
3. solid blue;
4. color bars;
5. checkerboard;
6. moving box.

### VGA timing skeleton

```verilog
module vga_timing_640x480 (
    input  wire clk_pix,
    input  wire reset,
    output reg  [9:0] x,
    output reg  [9:0] y,
    output wire active,
    output wire hsync,
    output wire vsync,
    output wire frame_start
);
    localparam H_ACTIVE = 640;
    localparam H_FP     = 16;
    localparam H_SYNC   = 96;
    localparam H_BP     = 48;
    localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;

    localparam V_ACTIVE = 480;
    localparam V_FP     = 10;
    localparam V_SYNC   = 2;
    localparam V_BP     = 33;
    localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

    always @(posedge clk_pix) begin
        if (reset) begin
            x <= 0;
            y <= 0;
        end else begin
            if (x == H_TOTAL - 1) begin
                x <= 0;
                if (y == V_TOTAL - 1)
                    y <= 0;
                else
                    y <= y + 1;
            end else begin
                x <= x + 1;
            end
        end
    end

    assign active = (x < H_ACTIVE) && (y < V_ACTIVE);

    // Negative sync polarity for classic 640x480 VGA.
    assign hsync = ~((x >= H_ACTIVE + H_FP) &&
                     (x <  H_ACTIVE + H_FP + H_SYNC));

    assign vsync = ~((y >= V_ACTIVE + V_FP) &&
                     (y <  V_ACTIVE + V_FP + V_SYNC));

    assign frame_start = (x == 0) && (y == 0);
endmodule
```

### Checkpoint

The monitor shows stable color bars with no rolling, flickering, or bad colors.

### Hints

- If the monitor says “out of range,” check pixel clock and totals.
- If the image is shifted, check front/back porch values.
- If colors are wrong, check VGA DAC pin assignments and bit ordering.
- If the whole image flickers, check PLL reset/lock and clock domain handling.

---

## Milestone 4 — Framebuffer Scanout

### Goal

Replace procedural test patterns with pixels read from a framebuffer.

### First framebuffer format

Use logical `320×240` RGB565:

```text
bytes_per_pixel = 2
framebuffer_size = 320 × 240 × 2 = 153,600 bytes
```

If you use double buffering:

```text
double_buffer_size = 2 × 153,600 = 307,200 bytes
```

This is small enough to debug comfortably and large enough for LVGL widgets.

### Scaling to VGA

For 2× scaling:

```verilog
src_x = vga_x >> 1;  // 0..319
src_y = vga_y >> 1;  // 0..239
addr  = src_y * 320 + src_x;
```

### RGB565 expansion to VGA RGB

If your VGA DAC wants 8-bit red, green, blue channels:

```verilog
wire [4:0] r5 = pixel[15:11];
wire [5:0] g6 = pixel[10:5];
wire [4:0] b5 = pixel[4:0];

wire [7:0] r8 = {r5, r5[4:2]};
wire [7:0] g8 = {g6, g6[5:4]};
wire [7:0] b8 = {b5, b5[4:2]};
```

### Important design point: memory read latency

Real memory usually does **not** return pixel data in the same cycle that you request it. Your scanout logic should be pipelined:

```text
cycle N:     generate address for pixel X
cycle N + L: receive data for pixel X
cycle N + L: output data aligned with delayed active/hsync/vsync
```

Delay `active`, `hsync`, and `vsync` by the same number of cycles as the framebuffer read latency.

### Checkpoint

The FPGA displays a framebuffer initialized to:

- solid colors;
- stripes;
- checkerboard;
- gradient.

### Hints

- Before involving HPS, initialize framebuffer memory from FPGA logic or a memory initialization file.
- If the image is diagonally torn or scrambled, your pitch/address math is probably wrong.
- If colors are weird but shapes are correct, suspect RGB565 bit ordering or byte order.
- If sync is stable but pixels lag horizontally, your memory latency compensation is wrong.

---

## Milestone 5 — HPS Writes Pixels Into the Framebuffer

### Goal

Write pixels from Linux into the framebuffer and see them on VGA.

### Software tests before LVGL

Write simple programs in this order:

1. clear screen to black;
2. fill screen red/green/blue;
3. draw rectangle;
4. draw horizontal/vertical lines;
5. draw checkerboard;
6. animate a moving square.

Example helper functions:

```c
#define FB_W 320
#define FB_H 240

typedef uint16_t pixel_t;

static inline pixel_t rgb565(uint8_t r, uint8_t g, uint8_t b) {
    return ((r & 0xF8) << 8) |
           ((g & 0xFC) << 3) |
           ((b & 0xF8) >> 3);
}

void fill_rect(pixel_t *fb, int pitch_pixels,
               int x, int y, int w, int h, pixel_t color) {
    for (int row = 0; row < h; row++) {
        pixel_t *dst = fb + (y + row) * pitch_pixels + x;
        for (int col = 0; col < w; col++) {
            dst[col] = color;
        }
    }
}
```

### Checkpoint

A Linux user-space test program can draw colored rectangles that appear correctly on the VGA monitor.

### Hints

- Test without LVGL first. LVGL should not be your first framebuffer writer.
- Print the mapped physical address and framebuffer size at startup.
- If a rectangle appears at the wrong place, check pitch. Pitch means bytes or pixels per row, depending on your code. Be consistent.
- If only every other pixel changes, check 16-bit versus 32-bit accesses.
- If writes do not appear until later, cache behavior may be involved.

---

## Milestone 6 — Minimal LVGL Port With Custom `flush_cb`

### Goal

Have LVGL render widgets into a draw buffer, then copy dirty rectangles into your framebuffer.

### LVGL concepts you need

LVGL needs:

1. `lv_init()`;
2. a display object;
3. draw buffer(s);
4. a `flush_cb`;
5. a tick source;
6. repeated calls to `lv_timer_handler()`;
7. optional input device(s).

### Suggested LVGL config

In `lv_conf.h`, start with:

```c
#define LV_COLOR_DEPTH 16
#define LV_USE_LOG 1
#define LV_USE_ASSERT_NULL 1
#define LV_USE_ASSERT_MALLOC 1
#define LV_USE_ASSERT_STYLE 1
#define LV_USE_ASSERT_MEM_INTEGRITY 1
#define LV_USE_ASSERT_OBJ 1
```

For early bring-up, enable logging and asserts. Disable them later if needed.

### Minimal custom flush callback

This is a simplified LVGL v9-style shape. Adjust includes and names based on the LVGL version you use.

```c
#include <stdint.h>
#include <string.h>
#include "lvgl/lvgl.h"

#define FB_W 320
#define FB_H 240

static uint16_t *g_fb = NULL;       // mmap'd framebuffer
static int g_pitch_pixels = FB_W;   // pixels per row, not bytes

static void de1soc_flush_cb(lv_display_t *display,
                            const lv_area_t *area,
                            void *px_map)
{
    int32_t x1 = area->x1;
    int32_t y1 = area->y1;
    int32_t x2 = area->x2;
    int32_t y2 = area->y2;

    if (x1 < 0) x1 = 0;
    if (y1 < 0) y1 = 0;
    if (x2 >= FB_W) x2 = FB_W - 1;
    if (y2 >= FB_H) y2 = FB_H - 1;

    int32_t w = x2 - x1 + 1;
    int32_t h = y2 - y1 + 1;

    const uint16_t *src = (const uint16_t *)px_map;

    for (int32_t row = 0; row < h; row++) {
        uint16_t *dst = g_fb + (y1 + row) * g_pitch_pixels + x1;
        memcpy(dst, src, (size_t)w * sizeof(uint16_t));
        src += w;
    }

    lv_display_flush_ready(display);
}
```

### Minimal LVGL display setup

```c
#define LVGL_BUF_LINES 40

static uint16_t lvgl_buf[FB_W * LVGL_BUF_LINES];

void setup_lvgl_display(void) {
    lv_display_t *disp = lv_display_create(FB_W, FB_H);

    lv_display_set_flush_cb(disp, de1soc_flush_cb);

    lv_display_set_buffers(
        disp,
        lvgl_buf,
        NULL,
        sizeof(lvgl_buf),
        LV_DISPLAY_RENDER_MODE_PARTIAL
    );
}
```

### Tick callback using Linux monotonic time

```c
#include <time.h>
#include <stdint.h>

static uint32_t tick_get_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint32_t)(ts.tv_sec * 1000u + ts.tv_nsec / 1000000u);
}
```

Call:

```c
lv_tick_set_cb(tick_get_ms);
```

### Main loop shape

```c
int main(void) {
    // 1. mmap FPGA registers
    // 2. mmap framebuffer
    // 3. test register ID
    // 4. clear framebuffer

    lv_init();
    lv_tick_set_cb(tick_get_ms);
    setup_lvgl_display();

    lv_obj_t *label = lv_label_create(lv_screen_active());
    lv_label_set_text(label, "LVGL on DE1-SoC!");
    lv_obj_center(label);

    while (1) {
        uint32_t wait_ms = lv_timer_handler();
        if (wait_ms == LV_NO_TIMER_READY) wait_ms = 5;
        if (wait_ms > 20) wait_ms = 20;

        struct timespec req = {
            .tv_sec = wait_ms / 1000,
            .tv_nsec = (wait_ms % 1000) * 1000000L
        };
        nanosleep(&req, NULL);
    }
}
```

### Checkpoint

A simple LVGL label or button appears on the VGA monitor.

### Hints

- If the flush callback runs once and then stops, check that `lv_display_flush_ready(display)` is called.
- If nothing is drawn, confirm `lv_timer_handler()` is called repeatedly.
- If animations are broken, confirm LVGL ticks are increasing correctly.
- If the display is garbage, test your `flush_cb` manually with a known pixel buffer before using LVGL widgets.
- If colors are wrong, check `LV_COLOR_DEPTH`, RGB565 channel order, and byte order.

---

## Milestone 7 — Input Through Linux evdev

### Goal

Control the LVGL UI with a USB mouse or touchscreen-like pointer.

### First input target

Use a USB mouse.

### Tasks

- Plug in the mouse.
- Identify event device:

```sh
cat /proc/bus/input/devices
ls /dev/input/event*
```

- If available, test with:

```sh
evtest /dev/input/eventX
```

- Connect LVGL’s evdev input backend or write a tiny input driver that reads Linux input events.

### Coordinate mapping

If your physical VGA is `640×480` but LVGL logical resolution is `320×240`, scale pointer coordinates:

```text
lvgl_x = raw_x / 2
lvgl_y = raw_y / 2
```

Depending on the event device, a mouse may report relative motion rather than absolute coordinates. For a normal mouse, keep your own cursor position:

```text
cursor_x += dx
cursor_y += dy
clamp cursor to 0..319 and 0..239
button_state = pressed/released
```

### Checkpoint

You can click an LVGL button with a USB mouse.

### Hints

- Start with pointer movement and left-click only.
- Add keyboard input later.
- Touchscreen support is easier after the mouse path works.
- For a normal mouse, you may want to draw an LVGL cursor object.

---

## Milestone 8 — VSYNC and Double Buffering

### Goal

Reduce tearing and make screen updates look cleaner.

### Single-buffer problem

With one framebuffer:

```text
HPS writes pixels while FPGA is reading pixels for VGA.
```

This can cause visible tearing if the HPS updates part of the screen while the scanout is in progress.

### Double-buffer solution

Use two framebuffers:

```text
front buffer: FPGA currently scans this out
back buffer:  HPS/LVGL writes here
```

At VSYNC:

```text
swap front/back buffers
```

### Control register idea

| Register | Purpose |
|---|---|
| `REG_FB0_BASE` | base/offset of buffer 0 |
| `REG_FB1_BASE` | base/offset of buffer 1 |
| `REG_FRONT_INDEX` | which buffer FPGA is scanning |
| `REG_BACK_INDEX` | which buffer HPS should draw into |
| `REG_SWAP_REQUEST` | HPS requests swap |
| `REG_SWAP_ACK` | FPGA confirms swap occurred at VSYNC |
| `REG_FRAME_COUNT` | increments every frame |

### Simple swap protocol

1. LVGL draws/copies into back buffer.
2. HPS sets `SWAP_REQUEST`.
3. FPGA sees request but waits until VSYNC/frame boundary.
4. FPGA swaps front/back buffer select.
5. FPGA increments `FRAME_COUNT` and sets `SWAP_ACK`.
6. HPS clears request or observes ack.

### Checkpoint

Animated rectangles or LVGL screens update without obvious tearing.

### Hints

- Keep the first version single-buffered. Do not add this until Milestone 6 works.
- If using LVGL partial rendering, double buffering gets trickier because the back buffer must contain a full valid previous frame.
- A simple but less efficient approach is full-frame rendering into the back buffer.
- A better approach is to copy dirty rectangles to both buffers or maintain LVGL direct/full render mode carefully.

---

## Milestone 9 — Performance Tuning

### Goal

Make the GUI feel responsive.

### Useful size calculations

| Resolution | Format | One buffer | Double buffer | Active scanout bandwidth at 60 Hz |
|---|---:|---:|---:|---:|
| `320×240` | RGB565 | `153,600 B` | `307,200 B` | about `9.2 MB/s` if scanned directly |
| `640×480` | RGB565 | `614,400 B` | `1,228,800 B` | about `36.9 MB/s` |
| `800×600` | RGB565 | `960,000 B` | `1,920,000 B` | about `57.6 MB/s` |

For your recommended first design, the FPGA physically scans `640×480`, but the logical framebuffer is `320×240` and each logical pixel is reused as a 2×2 block.

### Tuning checklist

- Use RGB565, not 32-bit color, at first.
- Use `-O2` or `-O3` for the HPS LVGL app.
- Avoid redrawing the whole screen unnecessarily.
- Increase LVGL draw buffer height if flush overhead is high.
- Use `memcpy` for row copies, not per-pixel writes, inside `flush_cb`.
- Make framebuffer memory contiguous and naturally aligned.
- Avoid printing inside the flush callback except for early debugging.
- Measure FPS with a frame counter register.
- Use `perf`, `time`, or simple timestamp logging to find slow parts.

### Checkpoint

Basic LVGL interactions feel usable, and moving widgets/buttons do not visibly crawl.

### Hints

- If performance is poor, measure first. Do not guess.
- A slow `flush_cb` is common. Make sure it copies rows efficiently.
- If HPS-to-FPGA writes are too slow, consider HPS DDR framebuffer as a later architecture.
- Complex LVGL themes, shadows, opacity, and anti-aliasing can cost CPU time.

---

## Milestone 10 — Clean Linux Integration

### Goal

Make the project less hacky and more maintainable.

### Upgrade path

1. Replace raw `/dev/mem` register mapping with UIO.
2. Put hardware addresses in device tree instead of hard-coded constants.
3. Add a small kernel driver only if needed.
4. Consider exposing the video output as `/dev/fb0`.
5. Later, consider DRM/KMS if you want a more modern Linux display path.

### Why UIO is a good intermediate step

UIO lets user-space programs map hardware registers and handle interrupts with less custom kernel code than a full driver.

### Checkpoint

The LVGL app starts without hard-coded mystery addresses and can be run consistently after reboot.

### Hints

- Keep the old `/dev/mem` test app in `sw/hps_pixel_test/` as a debugging fallback.
- Document your device tree changes carefully.
- Keep the register map stable once LVGL depends on it.

---

## Milestone 11 — Optional Nios V Version

### Goal

Reuse the proven FPGA display hardware with a Nios V soft processor.

### Why this is a good later project

Once the display hardware is known-good, Nios V only has to solve the software side:

- LVGL tick timer;
- framebuffer writes;
- input driver;
- memory allocation;
- optional RTOS integration.

### Nios V tasks

- Build a Nios V Platform Designer system.
- Add memory: on-chip RAM, FPGA SDRAM, or both.
- Add timer interrupt for LVGL tick.
- Add UART for debug logging.
- Add simple input: buttons first, then PS/2/USB/touch if desired.
- Port the same LVGL UI code used by the HPS project.
- Implement a Nios V version of the display `flush_cb`.

### Checkpoint

The same simple LVGL label/button screen runs from Nios V and appears on the same FPGA VGA output.

### Hints

- Do not start Nios V until the VGA/framebuffer hardware is solid.
- Use buttons/switches for first input instead of trying USB immediately.
- Start with a static UI, then add interaction.
- Keep the HPS version as a known-good reference.

---

# 8. Suggested Hardware Blocks

## 8.1 VGA timing block

Inputs:

- pixel clock;
- reset.

Outputs:

- `x`, `y` counters;
- `active_video`;
- `hsync`, `vsync`;
- `frame_start` or `vsync_edge`.

## 8.2 Framebuffer reader

Inputs:

- current VGA `x`, `y`;
- active video;
- selected framebuffer base;
- memory read interface.

Outputs:

- RGB565 pixel;
- valid signal aligned with sync signals.

## 8.3 RGB565-to-VGA converter

Inputs:

- RGB565 pixel;
- active video.

Outputs:

- VGA red/green/blue bus;
- black during blanking.

## 8.4 Control register block

Inputs:

- Avalon-MM or AXI-lite style bus from HPS;
- frame timing status from VGA block.

Outputs:

- enable;
- selected buffer;
- swap request/ack;
- debug LEDs;
- status values.

## 8.5 Optional scaler

For `320×240` logical to `640×480` physical:

```text
src_x = physical_x >> 1
src_y = physical_y >> 1
```

Later, you can implement:

- centering;
- integer scaling for other resolutions;
- nearest-neighbor only at first;
- bilinear scaling only as a stretch goal.

---

# 9. Proposed Register Map

This is a suggested map. Your actual base address will be assigned in Platform Designer.

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `REG_ID` | RO | Magic value, e.g. `0x4C56474C` (`LVGL`) |
| `0x04` | `REG_VERSION` | RO | Hardware version, e.g. `0x00010000` |
| `0x08` | `REG_CONTROL` | RW | bit 0 enable, bit 1 test pattern enable, bit 2 swap request |
| `0x0C` | `REG_STATUS` | RO | bit 0 in_vblank, bit 1 swap_ack, bit 2 busy |
| `0x10` | `REG_WIDTH` | RO/RW | logical width, start with 320 |
| `0x14` | `REG_HEIGHT` | RO/RW | logical height, start with 240 |
| `0x18` | `REG_PITCH_BYTES` | RO/RW | bytes per row, start with 640 |
| `0x1C` | `REG_FORMAT` | RO/RW | 0 = RGB565 |
| `0x20` | `REG_FB0_OFFSET` | RW | framebuffer 0 offset/base |
| `0x24` | `REG_FB1_OFFSET` | RW | framebuffer 1 offset/base |
| `0x28` | `REG_FRONT_INDEX` | RO | current scanout buffer |
| `0x2C` | `REG_FRAME_COUNT` | RO | increments every frame |
| `0x30` | `REG_IRQ_ENABLE` | RW | optional interrupt enable |
| `0x34` | `REG_IRQ_STATUS` | RW1C | optional interrupt status |
| `0x38` | `REG_SCRATCH` | RW | software/hardware readback test |

Good register map rules:

- include a magic ID;
- include a version;
- include a scratch register;
- keep reserved gaps for future expansion;
- document every bit;
- do not change offsets once software depends on them.

---

# 10. Memory Map Notes

The DE1-SoC has several possible memory regions depending on the design loaded into the FPGA and the HPS bridge setup.

Important warning: **do not blindly copy addresses from tutorials into your custom design**. Tutorial systems often use a prebuilt “DE1-SoC Computer” memory map. Your Platform Designer system may assign different base addresses.

Things to document in `docs/memory-map.md`:

```text
Register block base:      0x????????
Register block span:      0x????????
Framebuffer base/window:  0x????????
Framebuffer span:         0x????????
Logical width:            320
Logical height:           240
Pixel format:             RGB565
Pitch bytes:              640
Buffers:                  1 or 2
```

Useful DE1-SoC reference facts from common university examples:

- the bridge reset register is documented at `0xFFD0501C` in the Intel FPGA University Program DE1-SoC Computer manual;
- the lightweight HPS-to-FPGA bridge is often used for small FPGA peripherals/control registers;
- prebuilt university computer systems may map FPGA peripherals around `0xFF200000` and FPGA memory windows elsewhere;
- custom Platform Designer projects can differ.

---

# 11. LVGL Integration Details

## 11.1 Rendering modes

LVGL v9 display buffers can use different render modes.

For this project, start with:

```c
LV_DISPLAY_RENDER_MODE_PARTIAL
```

Why:

- draw buffer can be smaller than the full screen;
- LVGL redraws only invalidated areas;
- memory use is low;
- easy to copy each dirty rectangle into the framebuffer.

Later options:

- `LV_DISPLAY_RENDER_MODE_DIRECT`: useful if LVGL renders directly into screen-sized framebuffer memory;
- `LV_DISPLAY_RENDER_MODE_FULL`: useful for traditional full-frame double buffering, but more bandwidth-heavy.

## 11.2 Draw buffer size

For `320×240` RGB565:

```text
One full frame = 320 × 240 × 2 = 153,600 bytes
1/10 frame    ≈ 15,360 bytes
40 lines      = 320 × 40 × 2 = 25,600 bytes
```

Start with 20–40 lines. If flush overhead is high, increase the buffer. If memory is tight, decrease it.

## 11.3 Color depth

Use:

```c
#define LV_COLOR_DEPTH 16
```

Make the FPGA expect RGB565 in the same order.

If colors are wrong:

- check red/blue swap;
- check byte order;
- check RGB565 bit layout;
- check LVGL config;
- check whether the HPS is writing little-endian halfwords and whether the FPGA reads the same order.

## 11.4 Flush callback rules

Your `flush_cb` must:

1. receive an area and pixel map;
2. copy exactly that rectangle into the framebuffer;
3. handle pitch correctly;
4. call `lv_display_flush_ready(display)` when done.

Do not do heavy logging inside `flush_cb` after early bring-up.

## 11.5 Tick and timer rules

LVGL needs time.

On Linux, use a monotonic clock callback:

```c
lv_tick_set_cb(tick_get_ms);
```

Then call:

```c
lv_timer_handler();
```

repeatedly in the main loop.

Symptoms of tick/timer problems:

| Symptom | Likely issue |
|---|---|
| Nothing ever redraws | `lv_timer_handler()` not called |
| Flush called once only | missing `lv_display_flush_ready()` |
| Animations broken | tick callback wrong |
| App crashes randomly | LVGL objects/buffers not static/global enough, memory too small, asserts disabled |

---

# 12. Build and Bring-Up Strategy

## Hardware bring-up order

1. LED blink.
2. HPS register read/write.
3. VGA color bars.
4. VGA framebuffer from initialized memory.
5. HPS writes framebuffer.
6. HPS writes moving rectangle.
7. LVGL writes framebuffer.
8. Input events.
9. Double buffering.
10. Cleanup and polish.

## Software bring-up order

1. `hello.c` on HPS.
2. `/dev/mem` register reader.
3. framebuffer clear/fill test.
4. rectangle draw test.
5. moving square test.
6. minimal LVGL label.
7. LVGL button.
8. mouse input.
9. LVGL demo.
10. your custom UI.

## Do not skip these tests

Before LVGL:

- register ID read works;
- scratch register works;
- solid framebuffer fills work;
- red/green/blue are correct;
- rectangle coordinates are correct.

Before double buffering:

- single framebuffer works;
- LVGL `flush_cb` works;
- frame counter works.

Before kernel driver work:

- user-space prototype works reliably.

---

# 13. Debugging Guide

## Problem: VGA monitor says “no signal”

Check:

- pixel clock frequency;
- PLL locked;
- VGA pin assignments;
- reset polarity;
- hsync/vsync polarity;
- top-level outputs connected;
- monitor accepts VGA mode.

Try:

- solid color pattern;
- slower/fixed reset release;
- known-good VGA timing module;
- check signals with SignalTap if available.

## Problem: VGA image rolls or is unstable

Check:

- horizontal total should be 800 for 640×480 mode;
- vertical total should be 525;
- sync pulse widths;
- pixel clock near 25 MHz;
- no accidental clock-domain crossing on sync signals.

## Problem: colors are wrong

Check:

- RGB pin order;
- RGB565 bit extraction;
- byte order from HPS writes;
- LVGL `LV_COLOR_DEPTH`;
- whether you accidentally use BGR instead of RGB.

## Problem: HPS cannot read FPGA registers

Check:

- FPGA is programmed;
- bridge is enabled;
- address map matches Platform Designer;
- Linux mapping uses page-aligned physical address;
- register block reset is released;
- bus width and byte enables are handled correctly.

## Problem: framebuffer writes do not show

Check:

- framebuffer address mapping;
- pitch math;
- 16-bit writes versus 32-bit writes;
- cache effects;
- FPGA scanout is reading the same memory that HPS writes;
- test pattern mode is disabled.

## Problem: LVGL flush callback is not called

Check:

- display object created;
- buffers set;
- flush callback set;
- `lv_timer_handler()` called;
- something invalidated/redrawn;
- LVGL init completed.

## Problem: LVGL flush callback called once then stops

Almost always:

```c
lv_display_flush_ready(display);
```

is missing or called with the wrong display pointer.

## Problem: UI is slow

Check:

- compiler optimization;
- `flush_cb` row-copy efficiency;
- draw buffer size;
- resolution;
- LVGL theme effects;
- excessive logging;
- full-screen redraws;
- HPS-to-FPGA write bandwidth.

## Problem: tearing

Use:

- VSYNC-aware swaps;
- double buffering;
- frame counter;
- avoid updating front buffer during scanout.

## Problem: input device does not work

Check:

```sh
cat /proc/bus/input/devices
ls -l /dev/input/event*
```

Then verify:

- correct event device;
- permissions;
- relative versus absolute input;
- coordinate scaling;
- LVGL input device linked to the correct display.

---

# 14. Common Design Traps

## Trap 1 — Trying to write the final system first

Avoid this. Build color bars, then framebuffer, then HPS rectangles, then LVGL.

## Trap 2 — Mixing physical and logical resolution

Keep these names clear:

```text
logical framebuffer: 320×240
physical VGA output: 640×480
scale factor: 2×
```

## Trap 3 — Confusing pitch and width

Width is visible pixels. Pitch is memory distance between rows.

For RGB565 320-wide tightly packed buffer:

```text
width pixels = 320
pitch bytes = 640
pitch pixels = 320
```

## Trap 4 — Ignoring memory latency

Framebuffer reads are usually pipelined. Delay sync/active signals to match pixel data.

## Trap 5 — Overusing `/dev/mem`

`/dev/mem` is fine for early experiments. Long term, use UIO or a proper driver.

## Trap 6 — Starting with full 640×480 LVGL

Full 640×480 RGB565 is not impossible, but it increases memory and bandwidth. Start with 320×240 scaled up.

## Trap 7 — Changing hardware addresses without updating software

Generate a memory map file and keep it versioned.

## Trap 8 — Debugging LVGL before debugging your framebuffer

Always verify your framebuffer with simple C drawing tests first.

---

# 15. Suggested Final Project Features

Once the MVP works, good extensions include:

- double buffering with VSYNC swap;
- frame counter and FPS display;
- USB mouse cursor;
- keyboard navigation;
- simple dashboard UI;
- animated widgets;
- hardware test-pattern mode;
- selectable resolution: 320×240 scaled, 640×480 native;
- UIO-based register mapping;
- Linux service that launches the LVGL app at boot;
- framebuffer screenshot dump over SSH;
- Nios V version using the same FPGA display core;
- hardware blitter or rectangle-fill accelerator;
- simple alpha-blend or color-conversion accelerator;
- DRM/KMS or fbdev driver.

---

# 16. Documentation You Should Write During the Project

Create these files early:

## `docs/architecture.md`

Include:

- block diagram;
- chosen framebuffer location;
- bridge usage;
- resolution;
- pixel format;
- final/optional features.

## `docs/memory-map.md`

Include:

- register base;
- register offsets;
- framebuffer base;
- buffer size;
- pitch;
- address source: Platform Designer, generated header, or device tree.

## `docs/bringup-log.md`

For every session, record:

```text
Date:
Goal:
What changed:
Commands run:
What worked:
What failed:
Next action:
Git commit:
```

## `docs/debug-notes.md`

Collect weird bugs and fixes:

- wrong colors;
- bad sync;
- bridge disabled;
- input device changed from event0 to event1;
- LVGL config mistakes.

---

# 17. Suggested Git Milestones

Use tags so you can always go back.

```sh
git tag m0-linux-boots
git tag m1-hps-registers
git tag m2-vga-colorbars
git tag m3-fb-scanout
git tag m4-hps-rectangles
git tag m5-lvgl-label
git tag m6-lvgl-input
git tag m7-double-buffer
```

Commit messages should be specific:

```text
hw: add 640x480 VGA timing generator
hw: add RGB565 framebuffer scanout path
sw: add HPS framebuffer rectangle test
sw: add initial LVGL flush callback
sw: add evdev mouse pointer input
```

---

# 18. Personal Project Checklist

Use this as your high-level progress tracker.

## Hardware

- [ ] FPGA project builds.
- [ ] Pin assignments are correct.
- [ ] LED test works.
- [ ] HPS bridge register block works.
- [ ] VGA timing works.
- [ ] VGA color bars work.
- [ ] Framebuffer scanout works.
- [ ] RGB565 conversion works.
- [ ] 2× scaling works.
- [ ] Frame counter works.
- [ ] Optional double buffering works.

## HPS/Linux

- [ ] Linux boots.
- [ ] Serial console works.
- [ ] Files can be copied to board.
- [ ] C program compiles/runs.
- [ ] FPGA registers can be mapped.
- [ ] Framebuffer can be mapped.
- [ ] Pixel test app works.
- [ ] USB input devices appear.
- [ ] Mouse events can be read.

## LVGL

- [ ] LVGL compiles for ARM/HPS.
- [ ] `lv_conf.h` uses RGB565.
- [ ] Tick callback works.
- [ ] `lv_timer_handler()` loop works.
- [ ] Display object created.
- [ ] Flush callback called.
- [ ] Flush callback copies rectangles correctly.
- [ ] Label appears.
- [ ] Button appears.
- [ ] Input clicks button.
- [ ] Demo or custom UI runs.

## Polish

- [ ] No hard-coded unexplained addresses.
- [ ] Register map documented.
- [ ] Build instructions documented.
- [ ] Known-good bitstream saved.
- [ ] Known-good SD image noted.
- [ ] Screenshots/photos captured.
- [ ] Final demo script written.

---

# 19. Useful Commands

## On the HPS Linux shell

```sh
uname -a
cat /proc/cpuinfo
cat /proc/iomem
cat /proc/bus/input/devices
ls -l /dev/input/
dmesg | tail -100
```

## Build a simple HPS C program natively

```sh
gcc -O2 -Wall -Wextra -o pixel_test pixel_test.c
sudo ./pixel_test
```

## Cross-compile shape from a host PC

The exact compiler prefix depends on your toolchain.

```sh
arm-linux-gnueabihf-gcc -O2 -Wall -Wextra -o pixel_test pixel_test.c
scp pixel_test root@BOARD_IP:/root/
```

## Quick input investigation

```sh
cat /proc/bus/input/devices
hexdump /dev/input/event0
```

`hexdump` is crude. `evtest` is much nicer if installed.

---

# 20. Resource Links

## LVGL

- LVGL display porting docs: <https://lvgl.io/docs/open/9.1/porting/display.html>
- LVGL tick interface: <https://lvgl.io/docs/open/9.1/porting/tick.html>
- LVGL timer handler: <https://lvgl.io/docs/open/9.1/porting/timer_handler.html>
- LVGL Linux framebuffer driver: <https://docs.lvgl.io/9.1/integration/driver/display/fbdev.html>
- LVGL Linux evdev input driver: <https://lvgl.io/docs/open/9.2/integration/driver/touchpad/evdev.html>
- LVGL Linux example repo: <https://github.com/lvgl/lv_port_linux>
- LVGL main GitHub repo: <https://github.com/lvgl/lvgl>

## DE1-SoC / Cyclone V SoC

- Terasic DE1-SoC product page: <https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=167&No=836>
- Intel FPGA Academic Program board resources: <https://www.intel.com/content/www/us/en/developer/articles/technical/fpga-academic-boards.html>
- DE1-SoC User Manual mirror: <https://people.ece.cornell.edu/land/courses/ece5760/DE1_SOC/DE1-SoC_User_manualv.1.2.2_revE.pdf>
- Intel FPGA University Program DE1-SoC Computer with ARM manual: <https://fpgacademy.org/Downloads/DE1-SoC_Computer_ARM.pdf>
- Cyclone V HPS Technical Reference Manual PDF: <https://www.intel.com/programmable/technical-pdfs/683126.pdf>

## HPS / FPGA bridges

- Altera/Intel Cyclone V and Arria V SoC device design guidelines, FPGA-to-SDRAM bridge section: <https://docs.altera.com/r/docs/683360/18.0/an-796-cyclone-v-and-arria-v-soc-device-design-guidelines/access-hps-sdram-via-the-fpga-to-sdram-interface>
- DE1-SoC Computer with ARM manual bridge section: <https://fpgacademy.org/Downloads/DE1-SoC_Computer_ARM.pdf>
- Cornell DE1-SoC examples and notes: <https://people.ece.cornell.edu/land/courses/ece5760/DE1_SOC/>

## Nios V

- Nios V Processor Developer Center: <https://www.altera.com/design/guidance/nios-v-developer>
- Nios V Embedded Processor Design Handbook: <https://docs.altera.com/r/docs/726952/25.3.1/nios-v-embedded-processor-design-handbook>
- Nios V Processor Software Developer Handbook: <https://docs.altera.com/r/docs/743810/current>

## VGA timing

- Project F video timings guide: <https://projectf.io/posts/video-timings-vga-720p-1080p/>
- VGA timing table: <https://martin.hinner.info/vga/timing.html>
- MIT 6.111 VGA explanation: <https://web.mit.edu/6.111/www/s2004/NEWKIT/vga.shtml>

## Linux userspace hardware access

- Linux UIO documentation: <https://docs.kernel.org/driver-api/uio-howto.html>
- Linux input event documentation: <https://docs.kernel.org/input/input.html>

---

# 21. Final Advice

The project is absolutely doable if you build it in the right order.

The winning strategy is:

```text
simple hardware first → simple HPS tests → LVGL only after pixels work → input → buffering → polish
```

The most important rule:

> Do not debug LVGL, VGA timing, HPS bridges, framebuffer memory, and input all at the same time.

Make each layer boring and reliable before moving up to the next one. That is how this turns from an overwhelming SoC/FPGA/Linux project into a series of achievable wins.
