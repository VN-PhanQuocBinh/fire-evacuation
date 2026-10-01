model Evacuation2DMVPGrid

global {
    float step <- 0.1 #s;
    geometry shape <- square(50 #m); // Phòng 50m x 50m
    
    int initial_people_count <- 201;
    int evacuated_count <- 0;
    
    // Đích đến là ô cell chứa cửa thoát hiểm
    cell exit_cell; 
    graph grid_graph;

    init {
        // 1. Tạo lối thoát hiểm (Cửa màu xanh phía trên)
        create exit_door {
            location <- {25, 1};
            shape <- box(4 #m, 1 #m, 1 #m);
        }

        // 2. Tạo tường bao quanh phòng
        create obstacle {
            shape <- line([{0,0}, {23,0}]) + line([{27,0}, {50,0}]) + 
                     line([{50,0}, {50,50}]) + line([{50,50}, {0,50}]) + line([{0,50}, {0,0}]);
            shape <- shape + 2.0;
        }
        
        // =========================================================
        // --- BỐ TRÍ NỘI THẤT & PHÒNG BẠN VĂN PHÒNG THỰC TẾ ---
        // =========================================================
        
        // A. Khu Lễ tân (Quầy lễ tân cong/ngang ngay gần cửa)
        create obstacle {
            location <- {25, 10};
            shape <- box(10 #m, 2 #m, 1 #m); // Quầy lễ tân chính
        }

        // B. Phòng Giám đốc / Server (Góc trên bên trái)
        // Tường ngang (chừa khoảng trống từ x=12 đến x=16 làm Cửa)
        create obstacle { location <- {6, 16}; shape <- box(12 #m, 1 #m, 1 #m); }
        // Tường dọc
        create obstacle { location <- {16, 8}; shape <- box(1 #m, 16 #m, 1 #m); }

        // C. Phòng họp lớn (Góc trên bên phải)
        // Tường dọc (chừa khoảng trống từ y=12 đến y=16 làm Cửa)
        create obstacle { location <- {34, 6}; shape <- box(1 #m, 20 #m, 1 #m); }
        // Tường ngang
        create obstacle { location <- {43, 16}; shape <- box(10 #m, 1 #m, 1 #m); }
        // Bàn họp lớn bên trong
        create obstacle { location <- {42, 8}; shape <- box(6 #m, 3 #m, 1 #m); }

        // D. Khu vực Làm việc Mở (Open Workspace) - 4 Cụm bàn làm việc nhân viên
        // Cụm 1: Trên - Trái
        create obstacle { location <- {10, 24}; shape <- box(12 #m, 4 #m, 1 #m); }
        create obstacle { location <- {10, 30}; shape <- box(12 #m, 4 #m, 1 #m); }
        
        // Cụm 2: Trên - Phải
        create obstacle { location <- {40, 24}; shape <- box(12 #m, 4 #m, 1 #m); }
        create obstacle { location <- {40, 30}; shape <- box(12 #m, 4 #m, 1 #m); }

        // Cụm 3: Dưới - Trái
        create obstacle { location <- {10, 38}; shape <- box(12 #m, 4 #m, 1 #m); }
        create obstacle { location <- {10, 44}; shape <- box(12 #m, 4 #m, 1 #m); }

        // Cụm 4: Dưới - Phải
        create obstacle { location <- {40, 38}; shape <- box(12 #m, 4 #m, 1 #m); }
        create obstacle { location <- {40, 44}; shape <- box(12 #m, 4 #m, 1 #m); }

        // E. Khu vực Pantry / Căn tin (Trung tâm phía dưới)
        create obstacle {
            location <- {25, 42};
            shape <- square(6 #m); // Đảo bếp/Bàn ăn lớn Pantry
        }

        // =========================================================
        // 4. Đánh dấu các ô bị vật cản đè lên
        ask cell {
            if (self overlaps union(obstacle collect each.shape)) {
                is_obstacle <- true;
                color <- #black;
            }
        }

        // Tìm ô cell làm cửa thoát hiểm
        exit_cell <- cell({25, 1});

        // 5. TẠO ĐỒ THỊ DI CHUYỂN TỪ CÁC Ô TRỐNG (Tự động tìm đường vòng qua vật cản)
        list open_cells <- cell where (!each.is_obstacle);
        grid_graph <- as_distance_graph(open_cells, 1.5);

        // 6. Khởi tạo người ngẫu nhiên ở các ô trống
        create people number: initial_people_count {
            cell start_cell <- one_of(open_cells);
            location <- start_cell.location;
            speed <- 1.2 #m/#s + rnd(-0.2, 0.3);
        }
    }
    
    reflex stop_simulation when: length(people) = 0 {
        do pause;
        write "Hoàn tất sơ tán toàn bộ đám đông!";
    }
}

// Định nghĩa Lưới 50x50 ô (neighbors: 8 giúp di chuyển linh hoạt 8 hướng)
grid cell width: 50 height: 50 neighbors: 8 {
    bool is_obstacle <- false;
    rgb color <- #white;
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
    
    reflex move_to_exit {
        // Di chuyển trên đồ thị grid_graph hướng tới exit_cell
        do goto target: exit_cell speed: speed on: grid_graph;
    }
    
    reflex check_evacuated {
        if (self distance_to {25, 1} < 2.5 #m) {
            evacuated_count <- evacuated_count + 1;
            do die;
        }
    }

    aspect default {
        draw circle(0.6 #m) color: #yellow border: #orange;
    }
}

grid my_cell width: 50 height: 50 {
    // Thuộc tính nội tại 'color' quyết định màu nền của từng ô lưới
    rgb color <- #white; 
}

experiment MainGUI type: gui {
    output {
        display Main_Display type: 2d {
            grid my_cell border: #red; // Hiển thị khung lưới xám nhạt
            species obstacle aspect: default;
            species exit_door aspect: default;
            species people aspect: default;
        }
        
        display Evacuation_Chart type: 2d refresh: every(1#cycles) {
            chart "Số người còn kẹt trong phòng" type: series {
                data "Người chưa thoát" value: length(people) color: #red;
                data "Đã thoát hiểm" value: evacuated_count color: #green;
            }
        }
    }
}