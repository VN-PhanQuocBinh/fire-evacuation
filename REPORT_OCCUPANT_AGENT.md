# Rà soát agent người (`occupant`)

Ngày rà soát: 11/11/2026. Phạm vi: luồng khởi tạo, nhận biết nguy hiểm, di chuyển, chuyển tầng, hàng đợi và trạng thái của `occupant` trong mô hình đang chạy qua `models/main.gaml`. Chỉ đọc mã nguồn; chưa chạy mô phỏng GAMA. Các lỗi dưới đây là kết luận từ luồng mã và tọa độ mặt bằng, không phải số liệu đo thực nghiệm.

## Kết luận nhanh

Hai hiện tượng được báo cáo đều có căn cứ: agent gọi `goto` theo đường thẳng mà không sử dụng tường/ô cản để tìm đường, và `flat_door_loc` không khớp cửa ra sảnh của các căn hộ tầng ở. Vì vậy chỉ sửa tọa độ đích sẽ chưa đủ: cần nối các cửa nội bộ, cửa căn hộ, hành lang, cửa thang và cửa ra ngoài thành một đường đi hợp lệ, rồi chặn các bước đi cắt qua vật cản.

Quy ước tọa độ: mặt bằng dùng `to_px(x) = 49 + 2x`, `to_py(y) = 16 + 2y` (`models/includes/1_building_architecture.gaml:25-34`). Các tọa độ dưới đây là tọa độ thế giới hiển thị, không phải mét địa phương.

## Phát hiện

### P0 — Đi xuyên tường vì không có định tuyến và kiểm tra va chạm

**Bằng chứng:** `prepare_and_delay`, `exit_room_to_lobby`, `navigate_lobby_to_stair`, `handle_stairs` lần lượt gọi `goto target: flat_door_loc`, `stair_door_pt` hoặc `ground_exit_pt` trực tiếp (`models/includes/4_people_evacuation.gaml:453-459,474-476,495-515,573-579`). Không đoạn nào đọc `grid_cell.is_obstacle`, giao cắt `plan_element` loại `wall`, hay một graph/path. Grid đã có cờ vật cản và danh sách ô trống (`models/includes/2_grid_rasterizer.gaml:25-32,82-106`) nhưng agent người không dùng. `goto` với một điểm đích không tự suy ra các bức tường chỉ được vẽ bằng agent khác.

**Ví dụ kiểm chứng bằng hình học:** agent tầng trệt ở `ESTATE_OFFICE` có thể bắt đầu tại `(52..63,48..58)` rồi hướng tới `flat_door_loc=(65,50)` (`4_people_evacuation.gaml:79-84,96-102,133-135`). Vách dọc tại x địa phương `5.4..5.6`, tức x thế giới `59.8..60.2`, trải từ y địa phương `15..22` (`1_building_architecture.gaml:228`); đoạn thẳng tới `(65,50)` từ bên trái vách cắt xuyên nó. Cửa vẽ tại x địa phương `5.4..5.6`, y `17.0..18.2` (`1_building_architecture.gaml:231`), nhưng đích `(65,50)` là x địa phương `8`, y `17`, bên kia cả vách tiếp theo tại x địa phương `7.9..8.1` (`:229-230`).

**Tác động:** đường đi, thời gian thoát nạn và phơi nhiễm khói không phản ánh hình học; có thể vào phòng khác, thang máy, riser hoặc qua tường bao. **Sửa:** biểu diễn tường/cột/nội thất cản trở theo từng tầng, làm ô cửa là lối thông thực sự, định tuyến A* trên các ô có thể đi (cấm cắt góc chéo qua hai ô tường) hoặc graph hành lang/cửa, kiểm tra đoạn di chuyển trong mỗi tick và tìm lại đường khi lối bị chặn. Grid hiện tại được rasterize cho tầng đang chọn, nên không dùng trực tiếp grid đó làm bản đồ chung cho toàn bộ cư dân ở các tầng khác.

### P0 — Tọa độ `flat_door_loc` của 6 căn hộ tầng ở không phải cửa ra sảnh

**Bằng chứng:** sáu đích được gán cố định tại `4_people_evacuation.gaml:150-178`; cửa ra sảnh tầng ở được vẽ tại `1_building_architecture.gaml:344-346,413-415` và đối xứng qua tâm (`:61-76,304-307,383-385`). Bảng so sánh:

| Mã | Đích đang dùng (thế giới) | Vị trí đích trên mặt bằng | Cửa ra sảnh đúng theo bản vẽ (xấp xỉ, thế giới) |
|---|---:|---|---:|
| X6 (Đông Bắc) | (82, 25.2) | x=16.5, y=4.6; cửa nội bộ phòng khách/bếp | (73.1, 30) |
| X1 (Đông giữa) | (84, 33.4) | x=17.5, y=8.7; cửa nội bộ căn giữa | (79, 31.6) |
| X2 (Đông Nam) | (82, 50.8) | x=16.5, y=17.4; khu cửa nội bộ căn góc | (73.1, 46) |
| X3 (Tây Nam) | (60, 50.8) | x=5.5, y=17.4; khu cửa nội bộ căn góc | (68.9, 46) |
| X4 (Tây giữa) | (58.2, 33.4) | x=4.6, y=8.7; cửa nội bộ căn giữa | (63, 31.6) |
| X5 (Tây Bắc) | (60, 25.2) | x=5.5, y=4.6; khu cửa nội bộ căn góc | (68.9, 30) |

**Cần kiểm tra thêm lối thông của cửa trên grid:** một số cửa tầng trệt được vẽ đè lên vách liền mạch, ví dụ Office tại x địa phương `7.9..8.1`, y `16.5..17.8`, trong khi vách cùng x trải y `15..22` (`1_building_architecture.gaml:229-230`). Rasterizer đánh dấu `wall` là obstacle nhưng không xóa cờ đó khi gặp `door` (`2_grid_rasterizer.gaml:86-101`). Nếu dùng grid để tìm đường, phải cắt lỗ ở vị trí cửa và kiểm tra kết quả sau rasterization; chỉ sửa đích của agent sẽ không mở được vách.

**Tác động:** agent chạm đích sai rồi đặt `flat_door_exited=true` ở bán kính 1 (`4_people_evacuation.gaml:474-490`), dù vẫn ở trong căn hộ. Sau đó nó chạy thẳng đến cửa thang, xuyên các vách còn lại. **Sửa:** lưu cửa ra sảnh riêng cho từng căn; với điểm sinh trong từng phòng, xác định chuỗi cửa nội bộ trước cửa căn hộ. Chỉ đổi trạng thái `flat_door_exited` khi agent thực sự đi qua ranh cửa từ phía căn hộ sang phía sảnh.

### P1 — Vị trí xuất phát không gắn với một phòng có đường đi hợp lệ

**Bằng chứng:** mỗi căn góc có hình học gồm nhiều phòng phân tách bằng vách/cửa (`1_building_architecture.gaml:311-346`), nhưng agent được rải đều trên một hình chữ nhật lớn (`4_people_evacuation.gaml:150-155,180-182`). Với căn giữa, khoảng x `84.5..92.5` hoặc `49.5..57.5` đặt nhiều agent phía trong dãy phòng, trong khi đích cố định ở cửa nội bộ. Tầng trệt cũng rải theo chữ nhật (`:79-84,133-135`), không loại trừ tường, nội thất, vùng không thuộc phòng. Không có bước kiểm tra ô sinh là vùng đi được.

**Tác động:** agent có thể xuất phát ở phía kia của vách hoặc trong vật cản, và cùng một mã căn hộ không cho biết nó đang ở phòng nào để tìm đúng cửa. **Sửa:** chọn ngẫu nhiên trong polygon từng phòng/ô đi được với khoảng hở phù hợp bán kính người; lưu `room_id`, ánh xạ phòng → cửa nội bộ → cửa căn hộ.

### P1 — Chuyển tầng bằng bộ đếm, không đi trong buồng thang; đường ra tầng trệt cắt vách

**Bằng chứng:** hàng đợi cấp quyền rồi đặt `target_waypoint=inside_stair_pt` (`4_people_evacuation.gaml:220-230`), nhưng `handle_stairs` không gọi `goto` đến waypoint này; sau bốn tick nó tăng/giảm `current_floor` tại nguyên tọa độ (`:532-571`). Khi tới tầng 0, agent đi trực tiếp từ gần `(74.4,38)` đến `(71,59)` (`:51-55,573-579`). Tường đáy buồng thang tầng trệt ở y địa phương `13.4..13.6`, tức y thế giới `42.8..43.2`, x `74.2..79.2` (`1_building_architecture.gaml:182-188`); đoạn hướng tới cửa chính cắt vùng tường này. `stair_speed` được gán nhưng không điều khiển quãng đường hay thời gian chuyển tầng (`4_people_evacuation.gaml:312-313,533,552-569`).

**Tác động:** hình ảnh người dịch tầng tức thời, tốc độ thang theo tuổi không có hiệu lực đối với thời gian đến đất, và đường ra tầng trệt có thể xuyên vách. **Sửa:** mô hình hóa vị trí trên cầu thang riêng theo tầng/đoạn thang, thời gian đi theo chiều dài và `stair_speed`; tại tầng trệt dẫn qua cửa buồng thang ra sảnh, sau đó mới tới cửa ngoài.

### P1 — Một hàng đợi cửa thang dùng chung cho mọi tầng

**Bằng chứng:** chỉ tạo một `building_stair_door` tại `(74.4,38)` (`4_people_evacuation.gaml:53,57-70`); mọi agent ở các tầng thêm vào cùng `waiting_queue` (`:516-524`) và cùng bị giới hạn một người mỗi 1.82 giây (`:209-232`). Danh sách không phân theo `current_floor`; các tầng khác nhau chỉ khác biến số tầng, dùng cùng tọa độ 2D.

**Tác động:** người ở tầng 23 có thể chặn cửa tầng 4 dù là các cửa riêng; thời gian chờ tăng sai theo tổng dân số. **Sửa:** một hàng đợi và thời điểm qua cửa cho mỗi tầng, sau đó xử lý mật độ/lưu lượng chung của buồng thang bằng cơ chế riêng nếu cần.

### P1 — Tốc độ và bán kính đến đích không cùng tỷ lệ với mặt bằng

**Bằng chứng:** mặt bằng là 2 đơn vị thế giới trên 1 m (`1_building_architecture.gaml:25-34`); `base_speed` chú thích m/s nhưng truyền nguyên giá trị cho `goto speed:` (`4_people_evacuation.gaml:261-264,456-459,474-475,502-515`). Các ngưỡng khoảng cách `<=1.0`, `<=1.2`, `<=1.8` là đơn vị thế giới (`:477,507,517,576`), tương ứng khoảng 0.5, 0.6, 0.9 m trên bản vẽ. Điểm `(71,59)` nằm trước cửa chính vẽ ở y `59.7..60.3` (`1_building_architecture.gaml:241`); người có thể được ghi thoát khi còn ở trong sảnh (`4_people_evacuation.gaml:504-511,573-580`).

**Tác động:** thời gian chạy lệch hệ số xấp xỉ 2 so với tốc độ chú thích; sự kiện qua cửa và thoát xảy ra sớm. **Sửa:** thống nhất đơn vị (ví dụ đổi m/s sang 2 world-unit/s), dùng hình học cắt qua cửa và điểm ngoài tòa nhà để xác nhận thoát.

### P2 — Chờ nhận thức nhưng đã chạy về phía cửa

**Bằng chứng:** `prepare_and_delay` tăng `delay_timer` rồi ngay lập tức `goto flat_door_loc` với `0.7 * base_speed`, trước khi hết `pre_evacuation_delay` (`4_people_evacuation.gaml:453-468`). Chỉ khi hết delay mới chuyển sang `evacuating`.

**Tác động:** `pre_evacuation_delay` không còn là thời gian chưa bắt đầu di chuyển; có thể khiến agent tới cửa trước khi quyết định sơ tán. **Sửa:** nếu delay đại diện cho thời gian trước khi di chuyển thì giữ đứng yên (hoặc mô hình hoạt động chuẩn bị rõ ràng); bắt đầu path khi hết delay. Nếu chủ ý chuẩn bị bằng cách tiến về cửa, đổi định nghĩa/nhãn chỉ số để tránh diễn giải sai.

### P2 — Nhận biết và phơi nhiễm theo tầng/ô đang xem làm lệch hành vi khi đổi tầng quan sát

**Bằng chứng:** agent chỉ lấy khói/cháy ô grid tại vị trí của mình khi `current_floor = selected_floor` (`4_people_evacuation.gaml:358-365,430-437`); những tầng khác dựa vào `floor_smoke_density` tổng quát. Tối ưu đầu hàm có thể `return` sớm nếu tầng sạch theo biến tổng quát và không phải tầng đang xem (`:340-343`). Nhận biết lửa gốc dùng khoảng cách Euclid `<=14.0` trên cùng tầng mà không kiểm tra tường/cửa (`:413-420`).

**Tác động:** cùng một agent có thể đổi mức phơi nhiễm hoặc thời điểm phát hiện chỉ vì người dùng click xem tầng khác; người sau vách có thể nhận biết lửa như người cùng phòng. **Sửa:** lấy trạng thái ô theo bản đồ của `current_floor` cho tất cả agent; tính quan sát/lan khói theo phòng, cửa và đường đi, không dựa vào `selected_floor`.

### P2 — Kẹt trên tầng 23 nhưng vẫn giữ trạng thái đang rút lên

**Bằng chứng:** khi `retreating_upward`, `handle_stairs` tăng tầng đến 23, sau đó chỉ đặt `current_speed=0` ở nhánh `else` (`4_people_evacuation.gaml:564-569`). Reflex vẫn chạy mỗi tick và đầu reflex lại đặt `current_speed=stair_speed` (`:532-533`); không có trạng thái mắc kẹt hay quyết định tiếp theo. `target_waypoint` khi rút lên cũng không được dùng để di chuyển (`:549,552-571`).

**Tác động:** agent đứng ở cùng vị trí, lặp chuyển trạng thái tốc độ, nhưng thống kê vẫn coi là đang rút lên. **Sửa:** chuyển sang trạng thái `trapped`/sheltering, cập nhật phơi nhiễm tại vị trí thực và xác định rõ điều kiện cứu hộ hoặc đổi tuyến.

## Thứ tự xử lý đề xuất

1. Chuẩn hóa bản đồ đi được theo **từng tầng** và kiểm tra các ô cửa có thật sự thông qua tường; bảo đảm điểm sinh nằm trong ô đi được.
2. Gán phòng xuất phát và chuỗi cửa đúng cho từng căn; sửa `flat_door_loc`, chỉ đánh dấu đã ra căn khi qua ranh cửa.
3. Thay các lệnh `goto` thẳng bằng đường đi qua ô/graph hợp lệ; thêm kiểm tra va chạm theo mỗi bước và thử các tình huống bắt đầu ở mọi phòng.
4. Tách hàng đợi cửa thang theo tầng, mô hình hóa di chuyển trong cầu thang và lối từ thang ra cửa ngoài tầng trệt.
5. Thống nhất đơn vị mét/đơn vị thế giới, điều kiện hoàn tất thoát, delay và dữ liệu phơi nhiễm không phụ thuộc tầng đang quan sát.

## Kịch bản kiểm tra sau khi sửa

- Chọn cư dân trong từng phòng của X1–X6: vẽ quỹ đạo, xác nhận lần lượt qua cửa nội bộ, cửa căn hộ, hành lang, cửa thang; không đoạn nào giao cắt tường/cột.
- Chọn cư dân tầng trệt ở Nursery, Estate Office, Main Lobby: xác nhận đường qua các cửa tương ứng rồi ra **ngoài** cửa chính, không chỉ đến gần cửa.
- Cho hai người tới cửa thang ở hai tầng khác nhau cùng lúc: hàng đợi hai tầng độc lập; vị trí và thời gian đi cầu thang phù hợp `stair_speed`.
- Chạy cùng seed, đổi `selected_floor` nhiều lần trong khi cháy: đường đi, FED và kết quả của một agent không đổi chỉ vì thao tác xem tầng.

**Giới hạn xác minh:** không tìm thấy/chưa chạy phiên GAMA trong lần rà soát này; cần chạy các kịch bản trên để kiểm tra cú pháp GAML, chính xác hình học raster và hành vi `goto` theo phiên bản GAMA đang dùng. Không sửa code agent trong lần này.
