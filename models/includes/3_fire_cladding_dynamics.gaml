/**
 * Module: 3_fire_cladding_dynamics.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: MODULE LỬA & KHÓI — Cladding Fire Dynamics
 *   - Lan truyền lửa theo xác suất có hướng gió (anisotropic)
 *   - Lan truyền khói với Concentration Decay & Wind Bias
 *   - Khởi phát cháy tự động tại ô is_origin (Tủ lạnh Flat 16)
 *     hoặc cho phép Click chuột đặt điểm cháy thủ công
 *   - Dùng thuộc tính `color` (built-in GAMA grid) — đồng bộ với 2_grid_rasterizer.gaml
 *   - Tương thích GAMA 2025.6.4
 */

model fire_cladding_dynamics

import "2_grid_rasterizer.gaml"

global {
    // =========================================================================
    // THAM SỐ LỬA & KHÓI
    // =========================================================================
    float step <- 0.1 #s;

    // Hướng gió: vector (x, y). Âm y = hướng lên phía Bắc (lên màn hình)
    point wind_direction <- {0.2, -1.0};

    float fire_spread_probability  <- 0.025;  // Xác suất lan lửa mỗi bước
    float smoke_spread_probability <- 0.15;   // Xác suất lan khói mỗi bước
    float smoke_decay              <- 0.008;  // Suy giảm mật độ khói mỗi bước
    float fire_growth_rate         <- 0.02;   // Tốc độ tăng cường độ lửa

    // Điều khiển
    bool fire_started <- false;

    // =========================================================================
    // KHỞI TẠO MODULE LỬA (gọi sau rasterize_floor_plan)
    // =========================================================================
    action init_fire_module {
        // Tự động đặt lửa tại ô is_origin (Tủ lạnh Flat 16)
        list<grid_cell> origin_cells <- grid_cell where each.is_origin;
        if (!empty(origin_cells)) {
            ask origin_cells {
                burning       <- true;
                fire_power    <- 1.0;
                smoky         <- true;
                smoke_density <- 1.0;
                color         <- #red;   // built-in grid color
            }
            fire_started <- true;
            write "[Fire Module] Đám cháy khởi phát tại " + length(origin_cells) + " ô ORIGIN (Tủ lạnh Hotpoint).";
        } else {
            write "[Fire Module] Không tìm thấy ô ORIGIN. Hãy Click để đặt điểm cháy thủ công.";
        }
    }

    // Action cho phép Click chuột đặt điểm cháy thủ công
    action place_fire_at_click {
        if (fire_started) {
            write "[Fire Module] Đám cháy đã được khởi phát rồi.";
            return;
        }
        point click_loc <- #user_location;
        grid_cell target <- grid_cell closest_to click_loc;
        if (target = nil or target.is_obstacle) {
            write "[Fire Module] Không thể đặt lửa tại vị trí này (ngoài lưới hoặc là vật cản).";
            return;
        }
        ask target {
            burning       <- true;
            fire_power    <- 1.0;
            smoky         <- true;
            smoke_density <- 1.0;
            color         <- #red;   // built-in grid color
        }
        fire_started <- true;
        write "[Fire Module] Đám cháy thủ công đặt tại: " + click_loc;
    }

    // =========================================================================
    // REFLEX: LAN TRUYỀN KHÓI (Anisotropic + Concentration Decay)
    // =========================================================================
    reflex spread_smoke when: fire_started {
        float wind_mag <- norm(wind_direction);
        point norm_wind <- (wind_mag = 0.0) ? {0.0, 0.0} : (wind_direction / wind_mag);

        ask grid_cell where (each.smoky) {
            point src_loc     <- self.location;
            float src_density <- self.smoke_density;

            // Suy giảm mật độ khói tại ô hiện tại
            smoke_density <- max([smoke_density - smoke_decay, 0.0]);
            if (smoke_density <= 0.05 and !burning) {
                smoky <- false;
                color <- #transparent;   // built-in grid color
            }

            // Lan sang các ô lân cận không phải vật cản
            list<grid_cell> nb_open <- self.neighbors where (!each.is_obstacle);
            loop nb over: nb_open {
                point dir_vec <- {nb.location.x - src_loc.x, nb.location.y - src_loc.y};
                float dir_mag <- norm(dir_vec);
                if (dir_mag > 0.0) {
                    point norm_dir <- dir_vec / dir_mag;
                    float alignment <- (norm_wind = {0.0,0.0}) ? 0.0
                        : (norm_dir.x * norm_wind.x + norm_dir.y * norm_wind.y);
                    float dyn_prob  <- smoke_spread_probability * max([0.15, 1.0 + alignment * 2.5]);

                    if (rnd(1.0) < dyn_prob) {
                        nb.smoky         <- true;
                        float ratio      <- 0.65 + (max([alignment, 0.0]) * 0.20);
                        float transferred <- src_density * ratio;
                        nb.smoke_density <- min([max([nb.smoke_density, transferred]), 1.0]);
                        if (!nb.burning) {
                            int g <- int(230 - (nb.smoke_density * 180));
                            nb.color <- rgb(g, g, g, 180);   // built-in grid color
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // REFLEX: LAN TRUYỀN LỬA
    // =========================================================================
    reflex spread_fire when: fire_started {
        ask grid_cell where (each.burning) {
            // Tăng cường độ lửa dần dần
            fire_power <- min([fire_power + fire_growth_rate, 1.0]);

            // Màu lửa chuyển dần từ vàng → đỏ theo fire_power
            int r_val <- 255;
            int g_val <- int(200 * (1.0 - fire_power));
            color <- rgb(r_val, g_val, 0, 220);   // built-in grid color

            // Lan lửa sang ô lân cận
            ask neighbors where (!each.is_obstacle and !each.burning) {
                if (rnd(1.0) < fire_spread_probability) {
                    self.burning       <- true;
                    self.fire_power    <- 0.6;
                    self.smoky         <- true;
                    self.smoke_density <- 1.0;
                    self.color         <- rgb(255, 120, 0, 220);   // built-in grid color
                }
            }
        }
    }
}
