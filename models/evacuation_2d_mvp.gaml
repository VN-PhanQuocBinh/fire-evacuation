model Evacuation2DMVPGrid

grid cell width: 50 height: 50 neighbors: 8 {
    bool is_obstacle <- false;
    bool burning <- false;
    float fire_power <- 0.0;
    bool smoky <- false;
    float smoke_density <- 0.0;
    rgb color <- #white;
}

global {
    float step <- 0.1 #s;
    geometry shape <- square(50 #m);

    int initial_people_count <- 200;
    int evacuated_count <- 0;
    int casualties_count <- 0;

    point fire_start_location <- {25, 37};

    // Fire spreads slower than smoke
    float fire_spread_probability <- 0.03;
    float smoke_spread_probability <- 0.08;
    float smoke_decay <- 0.02;
    float fire_damage <- 8.0;
    float smoke_damage <- 1.5;

    cell exit_cell;
    graph grid_graph;

    init {
        // 1. Tạo lối thoát hiểm
        create exit_door {
            location <- {25, 1};
            shape <- box(4 #m, 1 #m, 1 #m);
        }

        // 2. Tạo tường bao quanh
        create obstacle {
            shape <- line([{0,0}, {23,0}]) +
                     line([{27,0}, {50,0}]) +
                     line([{50,0}, {50,50}]) +
                     line([{50,50}, {0,50}]) +
                     line([{0,50}, {0,0}]);
            shape <- shape + 2.0;
        }

        // A. Khu Lễ tân
        create obstacle {
            location <- {25, 10};
            shape <- box(10 #m, 2 #m, 1 #m);
        }

        // B. Phòng Giám đốc / Server
        create obstacle {
            location <- {6, 16};
            shape <- box(12 #m, 1 #m, 1 #m);
        }

        create obstacle {
            location <- {16, 8};
            shape <- box(1 #m, 16 #m, 1 #m);
        }

        // C. Phòng họp lớn
        create obstacle {
            location <- {34, 6};
            shape <- box(1 #m, 20 #m, 1 #m);
        }

        create obstacle {
            location <- {43, 16};
            shape <- box(10 #m, 1 #m, 1 #m);
        }

        create obstacle {
            location <- {42, 8};
            shape <- box(6 #m, 3 #m, 1 #m);
        }

        // D. Khu vực làm việc mở
        create obstacle {
            location <- {10, 24};
            shape <- box(12 #m, 3 #m, 1 #m);
        }

        create obstacle {
            location <- {10, 30};
            shape <- box(12 #m, 3 #m, 1 #m);
        }

        create obstacle {
            location <- {40, 24};
            shape <- box(12 #m, 3 #m, 1 #m);
        }

        create obstacle {
            location <- {40, 30};
            shape <- box(12 #m, 3 #m, 1 #m);
        }

        create obstacle {
            location <- {10, 38};
            shape <- box(12 #m, 3 #m, 1 #m);
        }

        create obstacle {
            location <- {10, 44};
            shape <- box(12 #m, 3 #m, 1 #m);
        }

        create obstacle {
            location <- {40, 38};
            shape <- box(12 #m, 3 #m, 1 #m);
        }

        create obstacle {
            location <- {40, 44};
            shape <- box(12 #m, 3 #m, 1 #m);
        }

        // E. Khu vực Pantry
        create obstacle {
            location <- {25, 42};
            shape <- square(6 #m);
        }

        // Đánh dấu các ô bị vật cản
        ask cell {
            if (self overlaps union(obstacle collect each.shape)) {
                is_obstacle <- true;
                color <- #black;
            }
        }

        // Xác định ô exit
        exit_cell <- cell({25, 1});

        // Exit phải luôn là ô có thể đi vào
        exit_cell.is_obstacle <- false;
        exit_cell.color <- #white;

        // Tạo graph sau khi xác định exit
        list open_cells <- cell where (!each.is_obstacle);
        grid_graph <- as_distance_graph(open_cells, 1.5);

        // Khởi tạo điểm cháy
        cell fire_origin <- cell(fire_start_location);

        if (fire_origin != nil and !fire_origin.is_obstacle) {
            fire_origin.burning <- true;
            fire_origin.fire_power <- 1.0;
            fire_origin.smoky <- true;
            fire_origin.smoke_density <- 1.0;
            fire_origin.color <- #red;
        }

        // Khởi tạo người
        list free_cells <- cell where (
            !each.is_obstacle and
            !each.burning
        );

        create people number: initial_people_count {
            cell start_cell <- one_of(free_cells);
            location <- start_cell.location;
            speed <- 1.2 #m/#s + rnd(-0.2, 0.3);
            health <- 100.0;
        }
    }

    // Khói lan nhanh hơn lửa
    reflex spread_smoke {
	    ask cell where (each.smoky) {
	
	        smoke_density <- max([smoke_density - smoke_decay, 0.0]);
	
	        ask neighbors where (!each.is_obstacle) {
	            if (rnd(1.0) < smoke_spread_probability) {
	                smoky <- true;
	                smoke_density <- max([smoke_density, 0.35]);
	
	                if (!self.burning) {
	                    self.color <- #gray;
	                }
	            }
	        }
	    }
	}

    // Lửa lan chậm hơn khói
    reflex spread_fire {
        ask cell where (each.burning) {

            fire_power <- min([fire_power + 0.03, 1.0]);

            ask neighbors where (
                !each.is_obstacle and
                !each.burning
            ) {
                if (rnd(1.0) < fire_spread_probability) {
                    burning <- true;
                    fire_power <- 1.0;
                    smoky <- true;
                    smoke_density <- 1.0;
                    color <- #red;
                }
            }
        }
    }

    reflex stop_simulation when: length(people) = 0 {
        do pause;
        write "Hoàn tất sơ tán toàn bộ đám đông!";
    }
}

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

species people skills: [moving] {
    float health;

    reflex move_to_exit {
        cell current_cell <- cell(location);

        if (current_cell != nil) {

            // Tìm đường ngắn nhất trên graph
            path evacuation_path <- path_between(
                grid_graph,
                current_cell,
                exit_cell
            );

            if (evacuation_path != nil) {

                list path_vertices <- evacuation_path.vertices;

                if (length(path_vertices) > 1) {

                    // Vertex tiếp theo trên đường đi
                    cell next_cell <- path_vertices[1];

                    // Tránh ô đang cháy
                    if (!next_cell.burning) {
                        do goto target: next_cell.location speed: speed;
                    } else {

                        // Nếu next cell đã cháy, tìm lại path
                        list safe_cells <- cell where (
                            !each.is_obstacle and
                            !each.burning
                        );

                        path safe_path <- path_between(
                            safe_cells,
                            current_cell,
                            exit_cell
                        );

                        if (safe_path != nil) {
                            list safe_vertices <- safe_path.vertices;

                            if (length(safe_vertices) > 1) {
                                cell safe_next <- safe_vertices[1];

                                do goto
                                    target: safe_next.location
                                    speed: speed;
                            }
                        }
                    }
                }
            }
        }

        // Damage từ lửa
        if (current_cell != nil) {
		
		    // Lửa gây damage mạnh
		    if (current_cell.burning) {
		        health <- health -
		            fire_damage * current_cell.fire_power;
		    }
		
		    // Khói gây damage nhẹ hơn
		    if (current_cell.smoky) {
		        health <- health - smoke_damage;
		    }
		
		    // Đứng gần lửa
		    list nearby_fire <- current_cell.neighbors where (
		        each.burning
		    );
		
		    if (length(nearby_fire) > 0) {
		        health <- health - 2.0;
		    }
		}

        // Agent chết
        if (health <= 0) {
            casualties_count <- casualties_count + 1;
            do die;
        }
    }

    // Đã tới cửa
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

        draw circle(0.5 #m)
            color: current_color
            border: #black;
    }
}

experiment MainGUI type: gui {
    output {
        display Main_Display type: 2d {
            grid cell border: #lightgray;
            species obstacle aspect: default;
            species exit_door aspect: default;
            species people aspect: default;
        }

        display Evacuation_Chart type: 2d refresh: every(1#cycles) {
            chart "Số người còn kẹt trong phòng" type: series {
                data "Người chưa thoát"
                    value: length(people)
                    color: #red;

                data "Đã thoát hiểm"
                    value: evacuated_count
                    color: #green;

                data "Thương vong"
                    value: casualties_count
                    color: #red;
            }
        }
    }
}