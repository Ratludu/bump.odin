/*
  This example is a port of the bump.lua demo by Enrique García Cota
  https://github.com/kikito/bump.lua

  MIT License
  Copyright (c) 2014 Enrique García Cota

  Modifications by Ratludu, 2026:
  - Ported to Odin (raylib)

  Original License:

  MIT LICENSE

  Copyright (c) 2014 Enrique García Cota

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be included
  in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

package main

import "bump"
import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

WINDOW_W :: 800
WINDOW_H :: 600

INSTRUCTIONS :: "bump.odin simple demo\n\n  arrows: move\n  tab: toggle debug info"

// how many collisions are happening this frame
cols_len: int

// Player ---------------------------------------------------------------------

Player :: struct {
	id:    bump.ItemId,
	x, y:  f64,
	w, h:  f64,
	speed: f64,
}

player := Player {
	x     = 50,
	y     = 50,
	w     = 20,
	h     = 20,
	speed = 80,
}

update_player :: proc(world: ^bump.World, dt: f64) {
	dx, dy := 0.0, 0.0
	if rl.IsKeyDown(.RIGHT) {
		dx = player.speed * dt
	} else if rl.IsKeyDown(.LEFT) {
		dx = -player.speed * dt
	}
	if rl.IsKeyDown(.DOWN) {
		dy = player.speed * dt
	} else if rl.IsKeyDown(.UP) {
		dy = -player.speed * dt
	}

	if dx != 0 || dy != 0 {
		actual_x, actual_y, cols, n, _ := bump.world_move(world, player.id, player.x + dx, player.y + dy)
		defer delete(cols)

		player.x, player.y = actual_x, actual_y
		cols_len = n

		for i in 0 ..< n {
			col := cols[i]
			buf: [128]u8
			msg := fmt.bprintf(
				buf[:],
				"col.other = %d, col.type = %v, col.normal = %d,%d",
				int(col.other),
				col.type,
				int(col.normal.x),
				int(col.normal.y),
			)
			console_print(msg)
		}
	}
}

draw_player :: proc() {
	draw_box(player.x, player.y, player.w, player.h, rl.Color{0, 255, 0, 255})
}

// Blocks ---------------------------------------------------------------------

blocks: [dynamic]bump.Rect

add_block :: proc(world: ^bump.World, x, y, w, h: f64) {
	bump.world_add(world, x, y, w, h)
	append(&blocks, bump.rect(x, y, w, h))
}

draw_blocks :: proc() {
	for b in blocks {
		draw_box(b.x, b.y, b.width, b.height, rl.Color{255, 0, 0, 255})
	}
}

// Helpers --------------------------------------------------------------------

draw_box :: proc(x, y, w, h: f64, c: rl.Color) {
	fill := rl.Color{c.r, c.g, c.b, 64}
	rl.DrawRectangle(i32(x), i32(y), i32(w), i32(h), fill)
	rl.DrawRectangleLines(i32(x), i32(y), i32(w), i32(h), c)
}

// Console (scrolling log of collisions) --------------------------------------

CONSOLE_SIZE :: 15

console: [CONSOLE_SIZE][129]u8

console_print :: proc(msg: string) {
	for i in 0 ..< CONSOLE_SIZE - 1 {
		console[i] = console[i + 1]
	}
	last := &console[CONSOLE_SIZE - 1]
	n := min(len(msg), 128)
	copy(last[:n], msg[:n])
	last[n] = 0
}

draw_console :: proc() {
	for i in 0 ..< CONSOLE_SIZE {
		alpha := u8(f32(i + 1) / f32(CONSOLE_SIZE) * 255)
		y := i32(580 - (CONSOLE_SIZE - 1 - i) * 12)
		rl.DrawText(cstring(&console[i][0]), 10, y, 10, rl.Color{255, 255, 255, alpha})
	}
}

// Debug grid overlay (port of bump_debug.lua) --------------------------------

draw_debug :: proc(world: ^bump.World) {
	cell := world.cell_size
	for cy, row in world.rows {
		for cx, c in row {
			if c == nil do continue
			lx, ly := bump.world_to_world(world, f64(cx), f64(cy))

			intensity := u8(min(f64(c.item_count) * 12 + 16, 255))
			rl.DrawRectangle(i32(lx), i32(ly), i32(cell), i32(cell), rl.Color{255, 255, 255, intensity})
			rl.DrawRectangleLines(i32(lx), i32(ly), i32(cell), i32(cell), rl.Color{255, 255, 255, 10})

			txt := rl.TextFormat("%d", c.item_count)
			tw := rl.MeasureText(txt, 10)
			rl.DrawText(
				txt,
				i32(lx) + (i32(cell) - tw) / 2,
				i32(ly) + (i32(cell) - 10) / 2,
				10,
				rl.Color{255, 255, 255, 64},
			)
		}
	}

	stats := rl.TextFormat(
		"fps: %d, collisions: %d, items: %d",
		rl.GetFPS(),
		i32(cols_len),
		i32(bump.world_count_items(world)),
	)
	sw := rl.MeasureText(stats, 10)
	rl.DrawText(stats, WINDOW_W - sw - 10, 580, 10, rl.WHITE)
}

draw_message :: proc() {
	rl.DrawText(INSTRUCTIONS, 550, 10, 10, rl.WHITE)
}

// Main -----------------------------------------------------------------------

main :: proc() {
	rl.InitWindow(WINDOW_W, WINDOW_H, "bump.odin simple demo")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	world := bump.world_new()
	defer bump.world_destroy(world)
	defer delete(blocks)

	player.id, _ = bump.world_add(world, player.x, player.y, player.w, player.h)

	// border walls
	add_block(world, 0, 0, 800, 32)
	add_block(world, 0, 32, 32, 600 - 32 * 2)
	add_block(world, 800 - 32, 32, 32, 600 - 32 * 2)
	add_block(world, 0, 600 - 32, 800, 32)

	// random blocks
	for _ in 0 ..< 30 {
		add_block(
			world,
			rand.float64_range(100, 600),
			rand.float64_range(100, 400),
			rand.float64_range(10, 100),
			rand.float64_range(10, 100),
		)
	}

	should_draw_debug := true

	for !rl.WindowShouldClose() {
		dt := f64(rl.GetFrameTime())

		cols_len = 0
		update_player(world, dt)

		if rl.IsKeyPressed(.TAB) do should_draw_debug = !should_draw_debug

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		draw_blocks()
		draw_player()
		if should_draw_debug {
			draw_debug(world)
			draw_console()
		}
		draw_message()

		rl.EndDrawing()
	}
}
