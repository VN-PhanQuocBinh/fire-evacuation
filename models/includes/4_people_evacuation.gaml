/**
 * Module: 4_people_evacuation.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: MODULE TÁC TỬ NGƯỜI & SƠ TÁN (REFACTORED OCCUPANT AGENT MODEL)
 *
 *   1. ĐỊNH NGHĨA THUỘC TÍNH (PROPERTIES):
 *      - Định danh & Không gian (agent_id, floor, flat, room, waypoints)
 *      - Thể chất & Vận động (age_group, base_speed, stair_speed, current_speed)
 *      - Nhận thức & Monte Carlo (behavior_state, pre_evacuation_delay, leave_door_open, thresholds)
 *      - Sinh lý ISO 13571 & Tâm lý (health, panic_level, fed_tox, fed_thermal, fed_critical_threshold)
 *
 *   2. ĐỊNH NGHĨA HÀNH VI (BEHAVIORS):
 *      - stay_in_flat -> preparing_evacuation -> evacuating -> waiting_at_door -> stairs / retreating -> evacuated / incapacitated
 *      - Động lực học ngạt khí ISO 13571 kết hợp thở dốc do hoảng sợ
 *      - Hàng đợi FIFO cổ chai tại cửa buồng thang SFPE (0.55 người/s)
 *      - Quay đầu leo lên tầng cao khi nhiệt độ buồng thang > 55°C
 *
 *   3. RANDOM SỐ LƯỢNG NGƯỜI TRONG CĂN PHÒNG:
 *      - Phân phối ngẫu nhiên (Poisson λ = 2.5) số người cho từng căn hộ
 *      - Random vị trí người rải đều bên trong ranh giới phòng
 *      - Random độ tuổi (Trẻ em 15%, Người lớn 65%, Người già 20%) và các phân phối Monte Carlo
 *
 *   4. PHÁT HỎA HOÀN TOÀN TÙY CHỌN BẰNG CLICK CHUỘT:
 *      - Không gán cứng căn hộ phát hỏa ban đầu
 *      - Người dùng click chuột vào bất kỳ ô nào trên mặt bằng để kích hoạt mồi lửa
 *      - Cư dân tự động nhận biết đám cháy dựa trên khoảng cách tới điểm click, nồng độ khói và ngọn lửa
 *
 * Tương thích: GAMA 2025.6.4
 */

model people_evacuation

import "3_fire_cladding_dynamics.gaml"

global {
    // =========================================================================
    // I. BIẾN QUẢN LÝ QUẦN THỂ & THỐNG KÊ
    // =========================================================================
    int total_occupants_count <- 0;
    int stay_put_count        <- 0;
    int preparing_count       <- 0;
    int evacuating_count      <- 0;
    int waiting_door_count    <- 0;
    int retreating_count      <- 0;
    int evacuated_count       <- 0;
    int casualties_count      <- 0;

    // Cấu hình: mô phỏng toàn tháp (~290 người) hoặc chỉ tầng đang xem (~15 người)
    bool full_tower_population <- true;

    // Tọa độ mốc không gian (chuẩn theo hệ tọa độ kiến trúc 1_building_architecture)
    point lobby_center_pt <- {71.0, 38.0}; // Tâm sảnh chung
    point stair_door_pt   <- {74.4, 38.0}; // Cửa buồng thang thoát hiểm
    point inside_stair_pt <- {76.5, 38.0}; // Chiếu nghỉ trong buồng thang
    point ground_exit_pt  <- {71.0, 59.0}; // Cửa chính thoát ra mặt đất tầng trệt

    // Cửa buồng thang quản lý hàng đợi SFPE
    stair_door building_stair_door;

    // =========================================================================
    // II. KHỞI TẠO MODULE & RANDOM SỐ LƯỢNG NGƯỜI TRONG CĂN PHÒNG
    // =========================================================================
    action init_evacuation_module {
        write "[Evacuation] Khởi tạo cửa buồng thang và sinh dân cư trong các căn hộ...";

        if (building_stair_door = nil) {
            create stair_door {
                location <- stair_door_pt;
                building_stair_door <- self;
            }
        }

        do spawn_random_occupants;
        write "[Evacuation] Hoàn tất khởi tạo " + total_occupants_count + " cư dân. Chờ người dùng click chuột phát hỏa...";
    }

    // Sinh cư dân cho Tầng trệt (Floor 0: Nhà trẻ, Ban Quản lý, Sảnh đón tiếp)
    action spawn_ground_floor_occupants {
        list<string> g_codes <- ["NURSERY_PLAY", "NURSERY_REST", "ESTATE_OFFICE", "MAIN_LOBBY"];
        list<float>  g_min_x <- [52.0, 72.0, 52.0, 67.0];
        list<float>  g_max_x <- [68.0, 80.0, 63.0, 77.0];
        list<float>  g_min_y <- [18.0, 18.0, 48.0, 48.0];
        list<float>  g_max_y <- [28.0, 28.0, 58.0, 58.0];
        list<point>  g_doors <- [{60.6, 30.0}, {72.0, 30.0}, {65.0, 50.0}, {71.0, 48.0}];
        list<int>    g_counts <- [6, 4, 3, 3]; // Tổng 16 người tầng trệt

        loop idx from: 0 to: 3 {
            string gcode   <- g_codes[idx];
            point  gdoor   <- g_doors[idx];
            float  gx1     <- g_min_x[idx];
            float  gx2     <- g_max_x[idx];
            float  gy1     <- g_min_y[idx];
            float  gy2     <- g_max_y[idx];
            int    n_count <- g_counts[idx];

            loop i from: 1 to: n_count {
                create occupant {
                    agent_id          <- "Floor_0_" + gcode + "_p" + i;
                    home_floor        <- 0;
                    current_floor     <- 0;
                    current_flat_code <- gcode;
                    flat_door_loc     <- gdoor;

                    // Đặc thù tầng trệt: Nhà trẻ gồm 80% trẻ em, 20% cô giáo
                    if (gcode = "NURSERY_PLAY" or gcode = "NURSERY_REST") {
                        age_group <- flip(0.80) ? "child" : "adult";
                    } else if (gcode = "ESTATE_OFFICE") {
                        age_group <- "adult";
                    } else {
                        age_group <- rnd_choice(["adult"::0.75, "elderly"::0.25]);
                    }

                    switch age_group {
                        match "child" {
                            base_speed <- min([max([gauss(0.90, 0.15), 0.45]), 1.20]);
                            fed_critical_threshold <- min([max([exp(0.0 + 0.35 * gauss(0, 1)), 0.3]), 1.1]);
                        }
                        match "adult" {
                            base_speed <- min([max([gauss(1.25, 0.20), 0.60]), 1.75]);
                            fed_critical_threshold <- min([max([exp(0.0 + 0.40 * gauss(0, 1)), 0.5]), 1.8]);
                        }
                        match "elderly" {
                            base_speed <- min([max([gauss(0.65, 0.15), 0.25]), 0.90]);
                            fed_critical_threshold <- min([max([exp(0.0 + 0.35 * gauss(0, 1)), 0.25]), 1.0]);
                        }
                    }
                    stair_speed   <- base_speed * 0.55;
                    current_speed <- base_speed;

                    // Tầng trệt phản ứng nhanh khi có còi báo
                    pre_evacuation_delay <- min([max([gauss(25.0, 10.0), 10.0]), 60.0]);

                    // Rải ngẫu nhiên trong phòng
                    location <- {gx1 + rnd(gx2 - gx1), gy1 + rnd(gy2 - gy1)};
                    target_waypoint <- location;
                }
            }
        }
    }

    action spawn_random_occupants {
        // 1. Sinh người cho Tầng trệt (Floor 0)
        do spawn_ground_floor_occupants;

        // 2. Sinh người cho các Tầng 1, 2, 3 và các tầng căn hộ phía trên
        int min_f <- 1;
        int max_f <- full_tower_population ? (test_max_floor - 1) : 4;
        if (max_f > 23) { max_f <- 23; }

        // Định nghĩa phạm vi 6 căn phòng/khu vực trên mặt bằng sàn 22m x 22m
        list<string> room_codes  <- ["X6", "X1", "X2", "X3", "X4", "X5"];
        list<float>  room_min_x  <- [79.5, 84.5, 79.5, 49.5, 49.5, 49.5];
        list<float>  room_max_x  <- [92.5, 92.5, 92.5, 62.5, 57.5, 62.5];
        list<float>  room_min_y  <- [16.5, 30.5, 46.5, 46.5, 30.5, 16.5];
        list<float>  room_max_y  <- [29.5, 37.5, 59.5, 59.5, 37.5, 29.5];
        list<point>  room_doors  <- [{82.0, 25.2}, {84.0, 33.4}, {82.0, 50.8}, {60.0, 50.8}, {58.2, 33.4}, {60.0, 25.2}];

        loop f from: min_f to: max_f {
            loop idx from: 0 to: 5 {
                string fcode   <- room_codes[idx];
                string room_id <- "Floor_" + f + "_" + fcode;

                // RANDOM SỐ LƯỢNG NGƯỜI TRONG CĂN PHÒNG (Phân phối Poisson trung bình λ = 2.5)
                int num_people <- rnd_choice([1::0.20, 2::0.35, 3::0.25, 4::0.15, 5::0.05]);

                point f_door <- room_doors[idx];
                float rx1    <- room_min_x[idx];
                float rx2    <- room_max_x[idx];
                float ry1    <- room_min_y[idx];
                float ry2    <- room_max_y[idx];

                loop i from: 1 to: num_people {
                    create occupant {
                        agent_id          <- room_id + "_p" + i;
                        home_floor        <- f;
                        current_floor     <- f;
                        current_flat_code <- fcode;
                        flat_door_loc     <- f_door;

                        // Rải vị trí ngẫu nhiên bên trong căn phòng
                        location <- {rx1 + rnd(rx2 - rx1), ry1 + rnd(ry2 - ry1)};
                        target_waypoint <- location;
                    }
                }
            }
        }

        total_occupants_count <- length(occupant);
        do update_population_statistics;
    }

    // Giảm tần suất thống kê: chạy mỗi 4 chu kỳ (2 giây/lần), tiết kiệm CPU
    reflex update_global_stats when: (cycle mod 4 = 0) {
        do update_population_statistics;
    }

    action update_population_statistics {
        stay_put_count     <- length(occupant where (each.behavior_state = "stay_in_flat"));
        preparing_count    <- length(occupant where (each.behavior_state = "preparing_evacuation"));
        evacuating_count   <- length(occupant where (each.behavior_state = "evacuating"));
        waiting_door_count <- length(occupant where (each.behavior_state = "waiting_at_door"));
        retreating_count   <- length(occupant where (each.behavior_state = "retreating_upward"));
    }
}

// =============================================================================
// CỬA BUỒNG THANG THOÁT HIỂM: HÀNG ĐỢI FIFO GIỚI HẠN LƯU LƯỢNG SFPE (0.55 người/s)
// =============================================================================
species stair_door {
    float door_width       <- 0.8;
    float effective_width  <- 0.5;   // W_eff = 0.8 - 2 * 0.15 = 0.5m
    float specific_flow    <- 1.1;   // F_s = 1.1 người/m/giây
    float max_flow_rate    <- 0.55;  // Lưu lượng tối đa 0.55 người/s
    float passage_interval <- 1.82;  // Giãn cách an toàn tối thiểu 1.82s

    float last_passage_time <- -100.0;
    list<occupant> waiting_queue <- [];

    // Xử lý hàng đợi O(1) trực tiếp tại đầu hàng
    reflex process_fifo_queue when: !empty(waiting_queue) {
        if ((time - last_passage_time) >= passage_interval) {
            occupant next_person <- first(waiting_queue);
            if (next_person != nil and next_person.behavior_state = "waiting_at_door" and !next_person.is_incapacitated) {
                ask next_person {
                    self.can_pass_door   <- true;
                    self.behavior_state  <- "evacuating";
                    self.target_waypoint <- inside_stair_pt;
                }
                last_passage_time <- time;
            }
            remove next_person from: waiting_queue;
        }
    }

    aspect default {
        draw rectangle(0.8, 1.4) at: location color: rgb(180, 40, 40) border: #black;
        if (!empty(waiting_queue)) {
            draw string(length(waiting_queue)) at: {location.x - 0.4, location.y - 1.2}
                color: #red font: font("Arial", 11, #bold);
        }
    }
}

// =============================================================================
// SPECIES OCCUPANT: TÁC TỬ NGƯỜI
// =============================================================================
species occupant skills: [moving] {
    // -------------------------------------------------------------------------
    // 1. PROPERTIES: ĐỊNH DANH & VỊ TRÍ KHÔNG GIAN
    // -------------------------------------------------------------------------
    string agent_id;
    int    home_floor;
    int    current_floor;
    string current_flat_code;
    point  flat_door_loc;
    point  target_waypoint;

    // -------------------------------------------------------------------------
    // 2. PROPERTIES: THỂ CHẤT & VẬN ĐỘNG (MONTE CARLO)
    // -------------------------------------------------------------------------
    string age_group;               // "child", "adult", "elderly"
    float  base_speed;              // Tốc độ bình thường (m/s)
    float  stair_speed;             // Tốc độ bước cầu thang (m/s)
    float  current_speed;           // Tốc độ thực tế sau khi bị khói/mật độ cản trở
    float  breathing_height <- 1.5; // Tầm thở chuẩn 1.5m

    // -------------------------------------------------------------------------
    // 3. PROPERTIES: NHẬN THỨC & RA QUYẾT ĐỊNH (MONTE CARLO)
    // -------------------------------------------------------------------------
    string behavior_state <- "stay_in_flat"; // stay_in_flat, preparing_evacuation, evacuating, waiting_at_door, retreating_upward, incapacitated, evacuated
    float  pre_evacuation_delay;    // Độ trễ phản ứng nhận thức (giây)
    float  delay_timer <- 0.0;
    bool   leave_door_open;         // Quyết định đóng/mở cửa khi tháo chạy (40% mở)
    float  temp_turnback_threshold; // Ngưỡng nhiệt khiến tác tử quay đầu (°C)
    float  vis_critical_threshold;  // Ngưỡng tầm nhìn tối thiểu (m)
    bool   flat_door_exited <- false;
    bool   can_pass_door    <- false;
    int    stair_step_ticks <- 0;

    // -------------------------------------------------------------------------
    // 4. PROPERTIES: SINH LÝ ISO 13571 & TÂM LÝ HOẢNG SỢ
    // -------------------------------------------------------------------------
    float health                 <- 100.0; // Sức khỏe (100% -> 0%)
    float panic_level            <- 0.0;   // Mức hoảng sợ (0.0 -> 1.0)
    float fed_tox                <- 0.0;   // Liều độc khí ngạt (CO, HCN)
    float fed_thermal            <- 0.0;   // Liều sốc nhiệt (> 50°C)
    float fed_critical_threshold <- 1.0;   // Ngưỡng gục ngã cá nhân
    bool  is_incapacitated       <- false;

    // -------------------------------------------------------------------------
    // KHỞI TẠO TÁC TỬ (MONTE CARLO PROBABILISTIC DISTRIBUTIONS)
    // -------------------------------------------------------------------------
    init {
        // Random nhóm tuổi: 15% Trẻ em, 65% Người lớn, 20% Người già
        age_group <- rnd_choice(["child"::0.15, "adult"::0.65, "elderly"::0.20]);

        // Random tốc độ theo độ tuổi (Truncated Normal)
        switch age_group {
            match "child" {
                base_speed <- min([max([gauss(0.90, 0.15), 0.45]), 1.20]);
                fed_critical_threshold <- min([max([exp(0.0 + 0.35 * gauss(0, 1)), 0.3]), 1.1]);
            }
            match "adult" {
                base_speed <- min([max([gauss(1.25, 0.20), 0.60]), 1.75]);
                fed_critical_threshold <- min([max([exp(0.0 + 0.40 * gauss(0, 1)), 0.5]), 1.8]);
            }
            match "elderly" {
                base_speed <- min([max([gauss(0.65, 0.15), 0.25]), 0.90]);
                fed_critical_threshold <- min([max([exp(0.0 + 0.35 * gauss(0, 1)), 0.25]), 1.0]);
            }
        }
        stair_speed   <- base_speed * 0.55; // Cầu thang giảm ~45% tốc độ
        current_speed <- base_speed;

        // Random thời gian trễ nhận thức (Lognormal Distribution)
        pre_evacuation_delay <- min([max([exp(4.2 + 0.6 * gauss(0, 1)), 60.0]), 600.0]);

        // Random xác suất quên đóng cửa khi tháo chạy (Bernoulli 40%)
        leave_door_open <- flip(0.40);

        // Random ngưỡng nhiệt quay đầu (Normal: trung bình 55°C, lệch chuẩn 5°C)
        temp_turnback_threshold <- min([max([gauss(55.0, 5.0), 45.0]), 65.0]);

        // Random ngưỡng tầm nhìn tối thiểu
        vis_critical_threshold  <- min([max([gauss(3.0, 0.7), 1.2]), 5.0]);
    }

    // =========================================================================
    // BEHAVIORS: CÁC HÀNH VI CỐT LÕI
    // =========================================================================

    // -------------------------------------------------------------------------
    // HÀNH VI 1: CẬP NHẬT TÂM LÝ HOẢNG SỢ & SINH LÝ FED (ISO 13571) - BẢO VỆ ĐIỀU KIỆN
    // -------------------------------------------------------------------------
    reflex update_psychology_and_tenability when: !is_incapacitated and behavior_state != "evacuated" {
        // Đọc thông số môi trường từ tầng hiện tại
        floor_level_agt fl_agt <- floor_map contains_key current_floor ? floor_map[current_floor] : nil;

        // Tối ưu hóa: Bỏ qua tính toán nếu tầng hoàn toàn sạch khói và không có cháy
        if (fl_agt != nil and fl_agt.floor_smoke_density < 0.01 and !fl_agt.interior_fire and current_floor != selected_floor and panic_level <= 0.05) {
            return;
        }

        float env_smoke <- 0.0;
        float env_temp  <- 25.0;
        bool  see_fire  <- false;
        if (fl_agt != nil) {
            env_smoke <- fl_agt.floor_smoke_density;
            if (fl_agt.clad_east > 0.1 or fl_agt.clad_west > 0.1 or fl_agt.clad_north > 0.1 or fl_agt.clad_south > 0.1) {
                see_fire <- true;
            }
            if (fl_agt.window_broken or fl_agt.interior_fire) {
                env_temp <- 25.0 + (env_smoke * 90.0);
            }
        }

        // Đọc trực tiếp từ ô lưới nếu đang xem tầng này
        if (current_floor = selected_floor) {
            grid_cell c <- grid_cell(location);
            if (c != nil) {
                if (c.smoky)   { env_smoke <- max([env_smoke, c.smoke_density]); }
                if (c.burning) { env_temp  <- max([env_temp, 160.0]); see_fire <- true; }
            }
        }

        // Mức hoảng sợ tăng khi thấy lửa, nhiễm khói hoặc bị kẹt
        float p_fire  <- see_fire ? 0.75 : 0.0;
        float p_smoke <- env_smoke * 0.85;
        float p_trap  <- (behavior_state = "retreating_upward") ? 0.95 :
                         ((behavior_state = "waiting_at_door") ? 0.40 : 0.0);
        float target_panic <- max([p_fire, p_smoke, p_trap]);
        panic_level <- panic_level + (target_panic - panic_level) * 0.10;
        panic_level <- min([1.0, max([0.0, panic_level])]);

        if (panic_level > 0.7) { leave_door_open <- true; }

        // Hiệu ứng thở dốc do hoảng loạn (Hyperventilation k_vent)
        float k_vent <- 1.0 + (1.8 * panic_level);

        // Tích lũy FED theo ISO 13571 (Hiệu chuẩn step = 0.5s: nhân hệ số x5)
        if (env_smoke > 0.05) {
            fed_tox <- fed_tox + (env_smoke * 0.0020 * k_vent);
        }
        if (env_temp > 50.0) {
            fed_thermal <- fed_thermal + (((env_temp - 50.0) / 60.0) ^ 1.33 * 0.0015);
        }

        float max_fed <- max([fed_tox, fed_thermal]);
        health <- max([0.0, (1.0 - (max_fed / fed_critical_threshold)) * 100.0]);

        // Kiểm tra gục ngã
        if (health <= 0.0 or max_fed >= fed_critical_threshold) {
            is_incapacitated <- true;
            behavior_state   <- "incapacitated";
            current_speed    <- 0.0;
            panic_level      <- 0.0;
            casualties_count <- casualties_count + 1;

            if (building_stair_door != nil and (building_stair_door.waiting_queue contains self)) {
                remove self from: building_stair_door.waiting_queue;
            }
        }
    }

    // -------------------------------------------------------------------------
    // HÀNH VI 2: NHẬN BIẾT ĐÁM CHÁY DO CLICK CHUỘT PHÁT HỎA & PHÁ VỠ STAY PUT
    // -------------------------------------------------------------------------
    reflex perceive_fire_and_break_stay_put when: behavior_state = "stay_in_flat" and !is_incapacitated {
        bool hazard_detected <- false;

        // 1. Nhận biết mồi lửa do người dùng click chuột
        if (fire_started) {
            // Nếu phát hỏa trên cùng tầng với tác tử
            if (fire_origin_floor = current_floor) {
                // Người ở gần điểm click chuột phát hiện thấy lửa ngay lập tức
                if (self distance_to fire_origin_loc <= 14.0) {
                    hazard_detected <- true;
                    pre_evacuation_delay <- min([max([gauss(40.0, 15.0), 15.0]), 90.0]); // Chạy rất nhanh
                }
            } else {
                // Đám cháy ở tầng khác: nhận biết qua khói hoặc lửa cladding lan tới
                floor_level_agt fl_agt <- floor_map contains_key current_floor ? floor_map[current_floor] : nil;
                if (fl_agt != nil and (fl_agt.floor_smoke_density > 0.15 or fl_agt.clad_east > 0.1 or fl_agt.clad_west > 0.1)) {
                    hazard_detected <- true;
                }
            }
        }

        // 2. Ô phòng mình đứng có khói hoặc lửa
        if (current_floor = selected_floor) {
            grid_cell c <- grid_cell(location);
            if (c != nil and (c.smoky or c.burning)) {
                hazard_detected <- true;
                pre_evacuation_delay <- min([pre_evacuation_delay, 30.0]);
            }
        }

        // 3. Chuông báo động hoặc tiếng ồn sơ tán (sau 25s kể từ khi phát hỏa cho các tầng dưới 0, 1, 2, 3)
        if (fire_started and current_floor <= 3 and time > 25.0) {
            hazard_detected <- true;
        }

        if (hazard_detected) {
            behavior_state  <- "preparing_evacuation";
            target_waypoint <- flat_door_loc;
        }
    }

    // -------------------------------------------------------------------------
    // HÀNH VI 3: CHUẨN BỊ & ĐỢI HẾT ĐỘ TRỄ NHẬN THỨC (PRE-EVACUATION DELAY)
    // -------------------------------------------------------------------------
    reflex prepare_and_delay when: behavior_state = "preparing_evacuation" and !is_incapacitated {
        delay_timer <- delay_timer + step;

        // Di chuyển gom về phía cửa chính căn phòng
        if (self distance_to flat_door_loc > 1.0) {
            do goto target: flat_door_loc speed: base_speed * 0.7;
        }

        if (delay_timer >= pre_evacuation_delay) {
            behavior_state  <- "evacuating";
            if (current_floor = 0) {
                target_waypoint <- ground_exit_pt;
            } else {
                target_waypoint <- lobby_center_pt;
            }
        }
    }

    // -------------------------------------------------------------------------
    // HÀNH VI 4: BƯỚC RA SẢNH & DÒ DẪM ĐẾN CỬA BUỒNG THANG
    // -------------------------------------------------------------------------
    reflex exit_room_to_lobby when: behavior_state = "evacuating" and !flat_door_exited and !is_incapacitated {
        do goto target: flat_door_loc speed: base_speed;

        if (self distance_to flat_door_loc <= 1.0) {
            flat_door_exited <- true;

            // Quyết định mở cửa: làm rò rỉ khói ra sảnh nếu phòng đang nhiễm khói
            if (leave_door_open) {
                floor_level_agt fl_agt <- floor_map contains_key current_floor ? floor_map[current_floor] : nil;
                if (fl_agt != nil and fl_agt.floor_smoke_density > 0.05) {
                    fl_agt.floor_smoke_density <- min([1.0, fl_agt.floor_smoke_density + 0.15]);
                }
            }
            if (current_floor = 0) {
                target_waypoint <- ground_exit_pt;
            } else {
                target_waypoint <- stair_door_pt;
            }
        }
    }

    reflex navigate_lobby_to_stair when: behavior_state = "evacuating" and flat_door_exited and !can_pass_door and !is_incapacitated {
        // Suy giảm tốc độ theo nồng độ khói sảnh (Frantzich & Nilsson)
        float spd_factor <- 1.0;
        floor_level_agt fl_agt <- floor_map contains_key current_floor ? floor_map[current_floor] : nil;
        if (fl_agt != nil and fl_agt.floor_smoke_density > 0.25) {
            spd_factor <- max([0.25, 1.0 - (fl_agt.floor_smoke_density * 0.75)]);
        }
        current_speed <- base_speed * spd_factor;

        if (current_floor = 0) {
            // Tầng trệt: chạy thẳng ra cửa chính CỬA CHÍNH thoát hiểm ngoài trời
            do goto target: ground_exit_pt speed: current_speed;
            if (self distance_to ground_exit_pt <= 1.8) {
                behavior_state  <- "evacuated";
                evacuated_count <- evacuated_count + 1;
                location        <- {-100.0, -100.0};
            }
        } else {
            // Tầng trên: di chuyển tới cửa buồng thang bộ
            do goto target: stair_door_pt speed: current_speed;

            // Đến gần cửa thang -> xếp hàng vào FIFO queue
            if (self distance_to stair_door_pt <= 1.2) {
                if (building_stair_door != nil) {
                    if (!(building_stair_door.waiting_queue contains self)) {
                        add self to: building_stair_door.waiting_queue;
                    }
                    behavior_state <- "waiting_at_door";
                    current_speed  <- 0.0;
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // HÀNH VI 5: DI CHUYỂN BUỒNG THANG & QUAY ĐẦU NẾU GẶP NHIỆT ĐỘ > 55°C
    // -------------------------------------------------------------------------
    reflex handle_stairs when: can_pass_door and !is_incapacitated and behavior_state != "evacuated" {
        current_speed <- stair_speed;

        // Đọc nhiệt độ buồng thang của tầng phía dưới
        floor_level_agt fl_below <- floor_map contains_key (current_floor - 1) ? floor_map[current_floor - 1] : nil;
        float stair_temp <- 25.0;
        if (fl_below != nil) {
            stair_temp <- 25.0 + (fl_below.floor_smoke_density * 65.0);
            if (fl_below.floor_id >= 6 and fl_below.floor_id <= 16 and fire_started and time > 300.0) {
                stair_temp <- max([stair_temp, 62.0]);
            }
        }

        // Quay đầu leo ngược lên tầng cao nếu nhiệt độ vượt ngưỡng chịu đựng
        if (behavior_state = "evacuating" and current_floor > 4 and stair_temp >= temp_turnback_threshold) {
            behavior_state  <- "retreating_upward";
            panic_level     <- 0.95; // Hào quang Tím Neon
            target_waypoint <- {inside_stair_pt.x, inside_stair_pt.y - 1.5};
        }

        stair_step_ticks <- stair_step_ticks + 1;

        // Mô phỏng nhịp bước chuyển tầng (~2.0 giây/tầng: 4 ticks x 0.5s)
        if (stair_step_ticks >= 4) {
            stair_step_ticks <- 0;

            if (behavior_state = "evacuating") {
                current_floor <- current_floor - 1;
                if (current_floor <= 0) {
                    current_floor   <- 0;
                    target_waypoint <- ground_exit_pt;
                }
            } else if (behavior_state = "retreating_upward") {
                if (current_floor < 23) {
                    current_floor <- current_floor + 1;
                } else {
                    current_speed <- 0.0; // Mắc kẹt tại tầng 23
                }
            }
        }

        // Đến tầng trệt và thoát ra ngoài an toàn
        if (current_floor = 0) {
            do goto target: ground_exit_pt speed: base_speed;
            if (self distance_to ground_exit_pt <= 1.8) {
                behavior_state  <- "evacuated";
                evacuated_count <- evacuated_count + 1;
                location        <- {-100.0, -100.0};
            }
        }
    }

    // =========================================================================
    // ASPECT HIỂN THỊ TRỰC QUAN 2 CHIỀU (SỨC KHỎE - HOẢNG SỢ)
    // =========================================================================
    aspect default {
        if (current_floor = selected_floor and behavior_state != "evacuated") {
            float r <- (age_group = "child") ? 0.35 : ((age_group = "adult") ? 0.50 : 0.45);

            // 1. Màu Lõi Thân theo Sức Khỏe (Health)
            rgb core_color <- #green;
            if (is_incapacitated) {
                core_color <- rgb(60, 60, 60);       // Đen xám tro: Tử vong
            } else if (health > 85.0) {
                core_color <- rgb(46, 204, 113);     // Xanh lục tươi: Khỏe mạnh
            } else if (health > 60.0) {
                core_color <- rgb(241, 196, 15);     // Vàng chanh: Kích ứng nhẹ
            } else if (health > 30.0) {
                core_color <- rgb(230, 126, 34);     // Cam đất: Nhiễm độc trung bình
            } else {
                core_color <- rgb(192, 57, 43);      // Đỏ thẫm: Nguy kịch ngạt thở
            }

            // 2. Vòng Hào Quang Hoảng Sợ (Aura Halo)
            if (!is_incapacitated and panic_level > 0.55) {
                float halo_r <- r * (1.2 + (panic_level * 0.6));
                rgb halo_col <- (panic_level > 0.80) ?
                                rgb(170, 40, 240, int(panic_level * 160)) : // Tím Neon tuyệt vọng
                                rgb(255, 70, 0, int(panic_level * 130));    // Đỏ cam sợ hãi
                draw circle(halo_r) color: halo_col;
            }

            // 3. Viền Tác tử theo Mức độ Hoảng sợ
            rgb border_color <- is_incapacitated ? #black :
                                ((panic_level > 0.80) ? rgb(160, 32, 240) :
                                ((panic_level > 0.35) ? rgb(255, 140, 0) : rgb(140, 150, 165)));

            draw circle(r) color: core_color border: border_color;

            // 4. Nhận diện Người Già (Double Ring)
            if (age_group = "elderly" and !is_incapacitated) {
                draw circle(r * 0.72) color: #transparent border: rgb(50, 50, 50);
            }

            // 5. Đánh dấu chữ X nếu gục ngã
            if (is_incapacitated) {
                draw line([{location.x - 0.25, location.y - 0.25}, {location.x + 0.25, location.y + 0.25}]) color: #black;
                draw line([{location.x - 0.25, location.y + 0.25}, {location.x + 0.25, location.y - 0.25}]) color: #black;
            }
        }
    }
}
