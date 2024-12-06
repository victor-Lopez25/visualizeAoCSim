package main

import sdl "vendor:sdl2"
import "core:strings"
import "core:time"
import "core:fmt"
import "core:mem"
import "core:os"

Key :: sdl.Keycode

Direction :: enum {
	Left,
	Right,
	Up,
	Down,
}

//AllDirs :: distinct u8
AllDirs :: [4]bool

SimData :: struct {
	lines: []string,
	initOutData: []u8,
	outData: []u8,
	previousCellDirections: []AllDirs,
	
	width, height: i32,
	initGuardPos: [2]i32,
	initGuardDir: Direction,
	
	guardPos: [2]i32,
	guardDir: Direction,
	
	exObstacleIdx: int,
	exObstaclePositions: [][2]i32,
	
	endCurrSimCounter: int,
	endCurrSim: b32,
}

sim_HandleNextObstacle :: proc(data: ^SimData) -> bool
{
	changedDir := false;
	switch data.guardDir {
		case .Left: {
			if (data.guardPos.x > 0 &&
					(data.lines[data.guardPos.y][data.guardPos.x - 1] == '#' || 
					 data.outData[data.guardPos.y*data.width + data.guardPos.x - 1] == 'O'))
			{
				changedDir = true;
				data.guardDir = .Up;
			}
		}
		case .Right: {
			if (data.guardPos.x < data.width - 1 && 
					(data.lines[data.guardPos.y][data.guardPos.x + 1] == '#' ||
					 data.outData[data.guardPos.y*data.width + data.guardPos.x + 1] == 'O'))
			{
				changedDir = true;
				data.guardDir = .Down;
			}
		}
		case .Up: {
			if (data.guardPos.y > 0 && 
					(data.lines[data.guardPos.y - 1][data.guardPos.x] == '#' ||
					 data.outData[(data.guardPos.y - 1)*data.width + data.guardPos.x] == 'O'))
			{
				changedDir = true;
				data.guardDir = .Right;
			}
		}
		case .Down: {
			if (data.guardPos.y < data.height - 1 && 
					(data.lines[data.guardPos.y + 1][data.guardPos.x] == '#' ||
					 data.outData[(data.guardPos.y + 1)*data.width + data.guardPos.x] == 'O'))
			{
				changedDir = true;
				data.guardDir = .Left;
			}
		}
	}
	
	return changedDir;
}

// returns if a loop has been found
@require_results
step :: proc(data: ^SimData) -> bool
{
	data.outData[data.guardPos.y*data.width + data.guardPos.x] = 'X';
	
	if data.previousCellDirections[data.guardPos.y*data.width + data.guardPos.x][data.guardDir] {
		return true;
	}
	data.previousCellDirections[data.guardPos.y*data.width + data.guardPos.x][data.guardDir] = true;
	
	changedDir := sim_HandleNextObstacle(data);
	if !changedDir {
		switch data.guardDir {
			case .Left: data.guardPos.x -= 1;
			case .Right: data.guardPos.x += 1;
			case .Up: data.guardPos.y -= 1;
			case .Down: data.guardPos.y += 1;
		}
	}
	
	return false;
}

update :: proc(data: ^SimData)
{
	//data.stepCounter += 1;
	
	//if !data.stopSim && (data.stepCounter % 8 == 0) {
	if !data.endCurrSim {
		foundLoop := step(data);
		if (data.guardPos.x < 0 || data.guardPos.x >= data.width ||
				data.guardPos.y < 0 || data.guardPos.y >= data.height) || foundLoop
		{
			data.endCurrSim = true;
			data.endCurrSimCounter += 1;
		}
	}
	else {
		data.endCurrSimCounter += 1;
	}
	
	// wait n frames
	if data.endCurrSimCounter > 60 {
		data.endCurrSimCounter = 0;
		data.endCurrSim = false;
		
		data.exObstacleIdx += 1;
		if data.exObstacleIdx == len(data.exObstaclePositions) {
			data.exObstacleIdx = 0;
		}
		
		data.guardPos = data.initGuardPos;
		data.guardDir = data.initGuardDir;
		
		mem.copy_non_overlapping(&data.outData[0], &data.initOutData[0], len(data.initOutData));
		mem.set(&data.previousCellDirections[0], 0, 
						len(data.previousCellDirections)*size_of(data.previousCellDirections[0]));
		
		obstP := data.exObstaclePositions[data.exObstacleIdx];
		data.outData[obstP.y*data.width + obstP.x] = 'O';
	}
}

render :: proc(renderer: ^sdl.Renderer, data: ^SimData)
{
	sdl.SetRenderDrawColor(renderer, 0, 0, 0, 0);
	sdl.RenderClear(renderer);
	
	for y : i32 = 0; y < data.height; y += 1
	{
		for x : i32 = 0; x < data.width; x += 1
		{
			switch data.outData[y*data.width + x] {
				case '.': {
					continue;
				}
				
				case 'X': {
					sdl.SetRenderDrawColor(renderer, 0, 86, 86, 255);
				}
				
				case 'O': {
					sdl.SetRenderDrawColor(renderer, 86, 86, 0, 255);
				}
				
				case '#': {
					sdl.SetRenderDrawColor(renderer, 200, 200, 200, 255);
				}
			}
			
			sdl.RenderDrawPoint(renderer, x, y);
		}
	}
	
	sdl.RenderPresent(renderer);
}

HandleNextObstacle :: proc(lines: []string, width, height, guardX, guardY: i32, guardDir: ^Direction, extraObstaclePos: [2]i32) -> bool
{
	changedDir := false;
	switch guardDir^ {
		case .Left: {
			if (guardX > 0 &&
					(extraObstaclePos.x == guardX - 1 && extraObstaclePos.y == guardY ||
					 lines[guardY][guardX - 1] == '#'))
			{
				changedDir = true;
				guardDir^ = .Up;
			}
		}
		case .Right: {
			if (guardX < width - 1 && 
					(extraObstaclePos.x == guardX + 1 && extraObstaclePos.y == guardY ||  
					 lines[guardY][guardX + 1] == '#'))
			{
				changedDir = true;
				guardDir^ = .Down;
			}
		}
		case .Up: {
			if (guardY > 0 &&
					(extraObstaclePos.x == guardX && extraObstaclePos.y == guardY - 1 || lines[guardY - 1][guardX] == '#'))
			{
				changedDir = true;
				guardDir^ = .Right;
			}
		}
		case .Down: {
			if (guardY < height - 1 &&
					(extraObstaclePos.x == guardX && extraObstaclePos.y == guardY + 1 || lines[guardY + 1][guardX] == '#'))
			{
				changedDir = true;
				guardDir^ = .Left;
			}
		}
	}
	
	return changedDir;
}

findObstaclePositions :: proc(obstacles: ^[dynamic][2]i32, data: ^SimData)
{
	for y : i32 = 0; y < data.height; y += 1
	{
		for x : i32 = 0; x < data.width; x += 1
		{
			if data.lines[y][x] == '#' do continue;
			if x == data.initGuardPos.x && y == data.initGuardPos.y do continue;
			
			extraObstaclePos := [2]i32{x,y};
			guardX := data.initGuardPos.x;
			guardY := data.initGuardPos.y;
			guardDir := data.initGuardDir;
			
			mem.set(raw_data(data.previousCellDirections), 0, 
							len(data.previousCellDirections)*size_of(data.previousCellDirections[0]));
			
			loop := false;
			// Move guard
			for guardX < data.width && guardX >= 0 && guardY < data.height && guardY >= 0
			{
				if data.previousCellDirections[guardY*data.width + guardX][guardDir] {
					loop = true;
					break;
				}
				data.previousCellDirections[guardY*data.width + guardX][guardDir] = true;
				
				changedDir := 
					HandleNextObstacle(data.lines, data.width, data.height, guardX, guardY, &guardDir, extraObstaclePos);
				if !changedDir {
					switch guardDir {
						case .Left: guardX -= 1;
						case .Right: guardX += 1;
						case .Up: guardY -= 1;
						case .Down: guardY += 1;
					}
				}
			}
			
			if loop {
				append(obstacles, extraObstaclePos);
			}
		}
	}
	
	mem.set(&data.previousCellDirections[0], 0, 
					len(data.previousCellDirections)*size_of(data.previousCellDirections[0]));
}

InitSimData :: proc(data: ^SimData, fileData: []u8) -> [dynamic][2]i32
{
	data.lines = strings.split_lines(string(fileData));
	data.width = i32(len(data.lines[0]));
	data.height = i32(len(data.lines));
	data.initOutData = make([]u8, data.width*data.height);
	
	for line, i in data.lines {
		mem.copy_non_overlapping(&data.initOutData[int(data.width)*i],
														 raw_data(line), len(line));
	}
	data.outData = make([]u8, len(data.initOutData));
	mem.copy_non_overlapping(&data.outData[0], &data.initOutData[0], len(data.initOutData));
	
	for y : i32 = 0; y < data.height; y += 1
	{
		for x : i32 = 0; x < data.width; x += 1
		{
			switch(data.lines[y][x]) {
				case '<': {
					data.initGuardPos = {x,y};
					data.initGuardDir = .Left;
					break;
				}
				case '>': {
					data.initGuardPos = {x,y};
					data.initGuardDir = .Right;
					break;
				}
				case '^': {
					data.initGuardPos = {x,y};
					data.initGuardDir = .Up;
					break;
				}
				case 'v': {
					data.initGuardPos = {x,y};
					data.initGuardDir = .Down;
					break;
				}
			}
		}
	}
	
	data.previousCellDirections = 
		make([]AllDirs, data.width*data.height);
	
	data.guardDir = data.initGuardDir;
	data.guardPos = data.initGuardPos;
	obstaclePositions: [dynamic][2]i32;
	append(&obstaclePositions, [2]i32{-1,-1});
	findObstaclePositions(&obstaclePositions, data);
	data.exObstaclePositions = obstaclePositions[:];
	return obstaclePositions;
}

main :: proc()
{
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator;
		mem.tracking_allocator_init(&track, context.allocator);
		context.allocator = mem.tracking_allocator(&track);
		
		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map));
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location);
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array));
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location);
				}
			}
			mem.tracking_allocator_destroy(&track);
		}
	}
	
	windowWidth : i32 = 1280;
	windowHeight : i32 = 720;
	window := sdl.CreateWindow("day6 vis", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, 
														 windowWidth, windowHeight, 
														 {.SHOWN, .RESIZABLE});
	assert(window != nil, "Could not create window");
	
	backend_idx: i32 = -1;
	if n := sdl.GetNumRenderDrivers(); n <= 0 {
		fmt.eprintln("No render drivers available");
	}
	else {
		for i : i32 = 0; i < n; i += 1
		{
			info: sdl.RendererInfo;
			if err := sdl.GetRenderDriverInfo(i, &info); err == 0 {
				// NOTE(bill): "direct3d" seems to not work correctly
				if info.name == "opengl" {
					backend_idx = i;
					break;
				}
			}
		}
	}
	
	renderer := sdl.CreateRenderer(window, backend_idx, sdl.RENDERER_ACCELERATED);
	assert(renderer != nil, "Could not create renderer");
	
	//fileData, ok := os.read_entire_file("sminput.txt");
	fileData, ok := os.read_entire_file("biginput.txt");
	assert(ok, "Could not read input file");
	
	simData: SimData;
	obstaclePositions := InitSimData(&simData, fileData);
	
	scrollY: i32;
	renderSize : f32 = 6.5;
	
	targetFPS : f32 = 300.0;
	deltaTime: f32;
	pause : b32 = true;
	quit : b32 = false;
	for !quit {
		startTick : time.Tick = time.tick_now();
		scrollY = 0;
		
		event: sdl.Event;
		for sdl.PollEvent(&event) {
#partial switch event.type {
			case .QUIT: quit = true;
			
			case .KEYDOWN: {
				if event.key.keysym.sym == Key.p {
					pause = !pause;
				}
			}
			
			case .MOUSEWHEEL: {
				scrollY = event.wheel.y;
			}
		}
	}
	
	renderSize += 0.325*f32(scrollY);
	
	if !pause {
		update(&simData);
	}
	
	sdl.RenderSetScale(renderer, renderSize, renderSize);
	render(renderer, &simData);
	
	////////////////////////////////
	// end frame
	duration : time.Duration = time.tick_since(startTick);
	deltaTime = 1000.0 / targetFPS;
	durationMS := f32(time.duration_milliseconds(duration));
	if(durationMS < deltaTime) {
		duration = time.Duration(1000000000 / u64(targetFPS)) - duration;
		//fmt.println("time sleep duration:", duration);
		time.accurate_sleep(duration);
	}
	else {
		fmt.println("Missed target fps:", duration);
	}
	duration = time.tick_since(startTick);
	deltaTime = f32(time.duration_seconds(duration));
	//fmt.printf("frame time: %f\n", deltaTime*1000.0);
}

delete(simData.initOutData);
delete(simData.outData);
delete(fileData);
delete(obstaclePositions);
delete(simData.previousCellDirections);
delete(simData.lines);
sdl.DestroyRenderer(renderer);
sdl.DestroyWindow(window);
sdl.Quit();
}