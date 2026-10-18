/**
 * Module: 4_people_evacuation.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: MODULE CON NGƯỜI & SƠ TÁN — Placeholder cho tích hợp tương lai
 *   - Khai báo skeleton species `evacuee` với skill moving
 *   - Sẵn sàng nhận dữ liệu từ grid (is_obstacle, burning, smoke_density)
 *   - Tương thích GAMA 2025.6.4
 */

model people_evacuation

import "3_fire_cladding_dynamics.gaml"

global {
    int    initial_people_count <- 0;   // Chưa khởi tạo người trong giai đoạn này
    int    evacuated_count      <- 0;
    int    casualties_count     <- 0;

    float  fire_damage  <- 8.0;
    float  smoke_damage <- 1.5;

    grid_cell exit_cell;    // Ô lối thoát hiểm
    graph     grid_graph;   // Đồ thị di chuyển (chỉ tính khi có người sơ tán)

    action init_evacuation_module {
        exit_cell <- grid_cell closest_to {93.0, 44.0};
        if (exit_cell != nil) { exit_cell.is_obstacle <- false; }

        // Chỉ xây dựng graph khi thật sự có người (tránh treo CPU khi khởi động)
        if (initial_people_count > 0) {
            list<grid_cell> open_cells <- grid_cell where (!each.is_obstacle);
            if (length(open_cells) > 1) {
                grid_graph <- as_distance_graph(open_cells, 1.5);
            }
        }

        write "[Evacuation Module] Module sẵn sàng (initial_people_count = " + initial_people_count + ").";
    }
}

// =============================================================================
// Species người sơ tán (placeholder — sẽ mở rộng trong giai đoạn 2)
// =============================================================================
species evacuee skills: [moving] {
    float health     <- 100.0;
    float base_speed <- 1.2 #m/#s;

    // Reflex di chuyển đến lối thoát (khi đã có lửa)
    reflex move_to_exit when: (fire_started and exit_cell != nil and grid_graph != nil) {
        grid_cell cur <- grid_cell(location);
        if (cur = nil) { return; }

        path evac_path <- path_between(grid_graph, cur, exit_cell);
        if (evac_path != nil) {
            list<grid_cell> verts <- evac_path.vertices;
            if (length(verts) > 1) {
                grid_cell nxt <- verts[1];
                if (!nxt.burning) {
                    float spd <- base_speed * (1.0 - (cur.smoke_density * 0.5));
                    do goto target: nxt.location speed: max([spd, 0.3 #m/#s]);
                }
            }
        }

        // Sát thương từ lửa & khói
        if (cur.burning) { health <- health - (fire_damage  * cur.fire_power);    }
        if (cur.smoky)   { health <- health - (smoke_damage * cur.smoke_density); }

        if (health <= 0.0) { casualties_count <- casualties_count + 1; do die; }
    }

    reflex check_evacuated when: (exit_cell != nil) {
        if (self distance_to exit_cell.location < 2.0) {
            evacuated_count <- evacuated_count + 1;
            do die;
        }
    }

    aspect default {
        rgb c <- (health > 75) ? #yellow : ((health > 50) ? #orange : ((health > 25) ? #red : #darkred));
        draw circle(0.4) color: c border: #black;
    }
}
