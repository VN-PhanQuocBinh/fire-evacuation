model Evacuation2DMVPGrid

// ============================================================================
// 1. ĐỊNH NGHĨA KHÔNG GIAN LƯỚI (GRID CELL)
// ============================================================================
grid cell width: 50 height: 50 neighbors: 8 {
    bool is_obstacle <- false;
    
    bool burning <- false;
    float fire_power <- 0.0;
    
    bool smoky <- false;
    float smoke_density <- 0.0;
    
    rgb color <- #white;
}

// ============================================================================
// 2. MÔ TRƯỜNG MÔ PHỎNG (GLOBAL)
// ============================================================================
global {
    float step <- 0.1 #s;
    geometry shape <- square(50 #m);

    int initial_people_count <- 200;
    int evacuated_count <- 0;
    int casualties_count <- 0;

    // --- CẤU HÌNH GIAI ĐOẠN 1: HƯỚNG GIÓ & ĐỘNG LỰC HỌC KHÓI ---
    point wind_direction <- {0.3, -1.0};
    
    float fire_spread_probability <- 0.03;
    float smoke_spread_probability <- 0.12;
    float smoke_decay <- 0.01;
    float fire_damage <- 8.0;
    float smoke_damage <- 1.5;

    // Biến điều khiển tương tác
    bool fire_started <- false;          // Đã đặt lửa chưa?
    point fire_start_location <- nil;    // Vị trí lửa (do người dùng click)

    cell exit_cell;
    graph grid_graph;

    init {
        // --------------------------------------------------------------------
        // A. TẠO CÁC VẬT THỂ MÔI TRƯỜNG & ĐỊA HÌNH
        // --------------------------------------------------------------------
        create exit_door {
            location <- {25, 1};
            shape <- box(4 #m, 1 #m, 1 #m);
        }

        create obstacle {
            shape <- line([{0,0}, {23,0}]) +
                     line([{27,0}, {50,0}]) +
                     line([{50,0}, {50,50}]) +
                     line([{50,50}, {0,50}]) +
                     line([{0,50}, {0,0}]);
            shape <- shape + 2.0;
        }

        // Quầy Lễ tân
        create obstacle { location <- {25, 10}; shape <- box(10 #m, 2 #m, 1 #m); }

        // Phòng Giám đốc / Server
        create obstacle { location <- {6, 16}; shape <- box(12 #m, 1 #m, 1 #m); }
        create obstacle { location <- {16, 8}; shape <- box(1 #m, 16 #m, 1 #m); }

        // Phòng họp lớn
        create obstacle { location <- {34, 6}; shape <- box(1 #m, 20 #m, 1 #m); }
        create obstacle { location <- {43, 16}; shape <- box(10 #m, 1 #m, 1 #m); }
        create obstacle { location <- {42, 8}; shape <- box(6 #m, 3 #m, 1 #m); }

        // Cụm Bàn làm việc
        create obstacle { location <- {10, 24}; shape <- box(12 #m, 3 #m, 1 #m); }
        create obstacle { location <- {10, 30}; shape <- box(12 #m, 3 #m, 1 #m); }
        create obstacle { location <- {40, 24}; shape <- box(12 #m, 3 #m, 1 #m); }
        create obstacle { location <- {40, 30}; shape <- box(12 #m, 3 #m, 1 #m); }
        create obstacle { location <- {10, 38}; shape <- box(12 #m, 3 #m, 1 #m); }
        create obstacle { location <- {10, 44}; shape <- box(12 #m, 3 #m, 1 #m); }
        create obstacle { location <- {40, 38}; shape <- box(12 #m, 3 #m, 1 #m); }
        create obstacle { location <- {40, 44}; shape <- box(12 #m, 3 #m, 1 #m); }

        // Khu Pantry
        create obstacle { location <- {25, 42}; shape <- square(6 #m); }

        // --------------------------------------------------------------------
        // B. CẬP NHẬT TRẠNG THÁI LƯỚI & TẠO ĐỒ THỊ DI CHUYỂN
        // --------------------------------------------------------------------
        ask cell {
            if (self overlaps union(obstacle collect each.shape)) {
                is_obstacle <- true;
                color <- #black;
            }
        }

        exit_cell <- cell({25, 1});
        exit_cell.is_obstacle <- false;
        exit_cell.color <- #white;

        list<cell> open_cells <- cell where (!each.is_obstacle);
        grid_graph <- as_distance_graph(open_cells, 1.5);

        // KHÔNG khởi tạo lửa ở đây nữa – chờ người dùng click

        // Khởi tạo Nhân viên
        list<cell> free_cells <- cell where (!each.is_obstacle);
        create people number: initial_people_count {
            cell start_cell <- one_of(free_cells);
            location <- start_cell.location;
            speed <- 1.2 #m/#s + rnd(-0.2, 0.3);
            health <- 100.0;
        }
        
        write ">>> Click chuột TRÁI vào một ô trống để bắt đầu đám cháy!";
    }

    // --------------------------------------------------------------------
    // ACTION TƯƠNG TÁC: Click để đặt điểm cháy
    // --------------------------------------------------------------------
    action start_fire_at_click { 
	    if (fire_started) {
	        write "Đám cháy đã được khởi tạo rồi. Không thể đặt thêm.";
	        return;
	    }
	    
	    point click_loc <- #user_location;
	    cell target_cell <- cell closest_to click_loc;   // an toàn hơn cell(click_loc)
	    
	    if (target_cell = nil) {
	        write "Click ngoài lưới!";
	        return;
	    }
	    
	    if (target_cell.is_obstacle) {
	        write "Không thể đặt lửa trên vật cản / tường!";
	        return;
	    }
	    
	    // Đặt lửa thành công
	    fire_started <- true;
	    fire_start_location <- target_cell.location;
	    
	    ask target_cell {
	        burning <- true;
	        fire_power <- 1.0;
	        smoky <- true;
	        smoke_density <- 1.0;
	        color <- #red;
	    }
	    
	    write ">>> Đám cháy đã bắt đầu tại: " + fire_start_location;
	}

    // --------------------------------------------------------------------
    // C. REFLEX QUẢN LÝ KHÓI – ANISOTROPIC + CONCENTRATION DECAY
    // --------------------------------------------------------------------
    reflex spread_smoke when: fire_started {
        float wind_magnitude <- norm(wind_direction);
        point normalized_wind <- (wind_magnitude = 0.0) ? {0,0} : (wind_direction / wind_magnitude);

        ask cell where (each.smoky) {
            point source_loc <- self.location;
            float source_density <- self.smoke_density;

            smoke_density <- max([smoke_density - smoke_decay, 0.0]);
            
            if (smoke_density <= 0.05 and !burning) {
                smoky <- false;
                color <- #white;
            }

            list<cell> target_neighbors <- self.neighbors where (!each.is_obstacle);
            
            loop nb over: target_neighbors {
                point dir_to_neighbor <- {nb.location.x - source_loc.x, nb.location.y - source_loc.y};
                float dir_magnitude <- norm(dir_to_neighbor);
                
                if (dir_magnitude > 0.0) {
                    point normalized_dir <- dir_to_neighbor / dir_magnitude;
                    
                    float alignment <- (normalized_wind = {0,0}) 
                        ? 0.0 
                        : (normalized_dir.x * normalized_wind.x + normalized_dir.y * normalized_wind.y);
                    
                    float dynamic_probability <- smoke_spread_probability * max([0.15, 1.0 + alignment * 2.5]);
                    
                    if (rnd(1.0) < dynamic_probability) {
                        nb.smoky <- true;
                        
                        float transfer_ratio <- 0.65 + (max([alignment, 0.0]) * 0.20);
                        float transferred_smoke <- source_density * transfer_ratio;
                        
                        nb.smoke_density <- max([nb.smoke_density, transferred_smoke]);
                        if (nb.smoke_density > 1.0) { nb.smoke_density <- 1.0; }

                        if (!nb.burning) {
                            int gray_val <- int(230 - (nb.smoke_density * 180));
                            nb.color <- rgb(gray_val, gray_val, gray_val);
                        }
                    }
                }
            }
        }
    }

    // --------------------------------------------------------------------
    // D. REFLEX QUẢN LÝ LỬA LAN TRUYỀN
    // --------------------------------------------------------------------
    reflex spread_fire when: fire_started {
        ask cell where (each.burning) {
            fire_power <- min([fire_power + 0.03, 1.0]);

            ask neighbors where (!each.is_obstacle and !each.burning) {
                if (rnd(1.0) < fire_spread_probability) {
                    self.burning <- true;
                    self.fire_power <- 1.0;
                    self.smoky <- true;
                    self.smoke_density <- 1.0;
                    self.color <- #red;
                }
            }
        }
    }

    reflex stop_simulation when: length(people) = 0 {
        do pause;
        write "Hoàn tất sơ tán toàn bộ đám đông!";
    }
}

// ============================================================================
// 3. ĐỊNH NGHĨA CÁC VẬT THỂ MÔI TRƯỜNG
// ============================================================================
species exit_door {
    aspect default {
        draw shape color: #green;
    }
}

species obstacle {
    aspect default {
        draw shape color: #black;
    }
}

// ============================================================================
// 4. HÀNH VI CON NGƯỜI
// ============================================================================
species people skills: [moving] {
    float health;

    reflex move_to_exit when: fire_started {
        cell current_cell <- cell(location);

        if (current_cell != nil) {
            path evacuation_path <- path_between(grid_graph, current_cell, exit_cell);

            if (evacuation_path != nil) {
                list<cell> path_vertices <- evacuation_path.vertices;

                if (length(path_vertices) > 1) {
                    cell next_cell <- path_vertices[1];

                    if (!next_cell.burning) {
                        float actual_speed <- speed * (1.0 - (current_cell.smoke_density * 0.5));
                        do goto target: next_cell.location speed: max([actual_speed, 0.3 #m/#s]);
                    } else {
                        list<cell> safe_cells <- cell where (!each.is_obstacle and !each.burning);
                        path safe_path <- path_between(safe_cells, current_cell, exit_cell);

                        if (safe_path != nil) {
                            list<cell> safe_vertices <- safe_path.vertices;
                            if (length(safe_vertices) > 1) {
                                cell safe_next <- safe_vertices[1];
                                float actual_speed <- speed * (1.0 - (current_cell.smoke_density * 0.5));
                                do goto target: safe_next.location speed: max([actual_speed, 0.3 #m/#s]);
                            }
                        }
                    }
                }
            }
        }

        // Cơ chế sát thương
        if (current_cell != nil) {
            if (current_cell.burning) {
                health <- health - (fire_damage * current_cell.fire_power);
            }
            if (current_cell.smoky) {
                health <- health - (smoke_damage * current_cell.smoke_density);
            }
            list<cell> nearby_fire <- current_cell.neighbors where (each.burning);
            if (!empty(nearby_fire)) {
                health <- health - (2.0 * length(nearby_fire));
            }
        }

        if (health <= 0) {
            casualties_count <- casualties_count + 1;
            do die;
        }
    }

    reflex check_evacuated {
        if (self distance_to {25, 1} < 2.5 #m) {
            evacuated_count <- evacuated_count + 1;
            do die;
        }
    }

    aspect default {
        rgb current_color;
        if (health > 75) {
            current_color <- #yellow;
        } else if (health > 50) {
            current_color <- #orange;
        } else if (health > 25) {
            current_color <- #red;
        } else {
            current_color <- #darkred;
        }
        draw circle(0.5 #m) color: current_color border: #black;
    }
}

// ============================================================================
// 5. GIAO DIỆN MÔ PHỎNG + TƯƠNG TÁC CHUỘT
// ============================================================================
experiment MainGUI type: gui {
    output {
        display Main_Display type: 2d {
            grid cell border: #lightgray;
            species obstacle aspect: default;
            species exit_door aspect: default;
            species people aspect: default;
            
            // --- TƯƠNG TÁC CLICK CHUỘT ---
            event #mouse_down {
                ask simulation {
                    do start_fire_at_click;
                }
            }
        }

        display Evacuation_Chart type: 2d refresh: every(1#cycles) {
            chart "Báo cáo Tình trạng Sơ tán & Thương vong" type: series {
                data "Người chưa thoát" value: length(people) color: #blue;
                data "Đã thoát hiểm" value: evacuated_count color: #green;
                data "Thương vong (Lửa/Khói)" value: casualties_count color: #red;
            }
        }
    }
}