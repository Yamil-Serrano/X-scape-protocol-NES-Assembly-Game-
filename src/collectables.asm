; ============================================================
; collectables.asm - Coin/Diamond/Key collectible logic
;
; Rules:
;   - Each coin gives +3 points
;   - Every 10 coins collected → next spawn is a diamond
;   - Each diamond gives +7 points + speed up
;   - 27 full cycles (10 coins + 1 diamond) = 999 points exactly
;   - At score 999 → next spawn is the key (player wins)
;   - Collecting the key sets game_won=1 and hides everything
;
; Math check: (10 × 3) + 7 = 37 pts/cycle × 27 cycles = 999 ✓
; ============================================================

.export update_collectable
.export draw_collectable
.export init_collectable
.export lfsr_tick

; --- Import zero page variables from main.asm ---
.importzp player_x, player_y, player_score
.importzp collectable_x, collectable_y, collectable_active
.importzp collectable_anim_timer, collectable_frame, collectable_dir
.importzp respawn_x, respawn_y, respawn_count, lfsr_seed
.importzp coin_count, diamond_mode, key_mode
.importzp mt_col, mt_row, temp
.importzp speed_bonus
.importzp tile_base, attr_base, ppu_lo
.importzp player_hp
.importzp enemy_move_timer, enemy2_move_timer
.importzp enemy_anim_timer, enemy2_anim_timer
.importzp game_won

; --- Import functions from main.asm ---
.import get_metatile

; ============================================================
; Init coin
; ============================================================
.proc init_collectable
  LDA #$A5
  STA lfsr_seed

  LDA #$01
  STA collectable_active
  LDA #$00
  STA collectable_anim_timer
  STA collectable_frame
  STA collectable_dir
  STA coin_count      ; Coins collected this cycle (0-9)
  STA diamond_mode    ; 0=normal coin, 1=diamond next
  STA key_mode      ; 0=normal, 1=key next (win condition)

  JSR respawn_coin
  RTS
.endproc

; ============================================================
; Decide next spawn
; Called after every collection to set what spawns next.
; Priority: key (score=999) > diamond (every 10 coins) > coin
; ============================================================
.proc decide_next_spawn
  LDA #$00
  STA diamond_mode
  STA key_mode

  ; --- Check win condition: score == 999 ($03E7) ---
  LDA player_score+1
  CMP #$03
  BNE check_diamond
  LDA player_score
  CMP #$E7
  BNE check_diamond
  LDA #$01
  STA key_mode
  RTS

check_diamond:
  ; --- Every 10 coins → diamond ---
  LDA coin_count
  CMP #10
  BNE done
  LDA #$00
  STA coin_count
  LDA #$01
  STA diamond_mode

done:
  RTS
.endproc

; ============================================================
; Lfsr_tick - 8-bit Galois LFSR, polynomial 0xB8
; Never returns 0, cycle of 255 distinct values
; ============================================================
.proc lfsr_tick
  LDA lfsr_seed
  LSR A
  BCC no_feedback
  EOR #$B8
no_feedback:
  STA lfsr_seed
  RTS
.endproc

; ============================================================
; Respawn coin
; Random position on passable metatile (00 or 03)
; Falls back to safe position table after 32 failed attempts
; ============================================================
.proc respawn_coin
  LDA #$00
  STA respawn_count

search_loop:
  INC respawn_count
  LDA respawn_count
  CMP #$20
  BEQ use_fallback

  JSR lfsr_tick
  JSR lfsr_tick
  AND #$0F
  STA respawn_x

  JSR lfsr_tick
  JSR lfsr_tick
  AND #$0F
  CMP #$0C
  BCS search_loop
  STA respawn_y

  LDA respawn_x
  STA mt_col
  LDA respawn_y
  STA mt_row
  JSR get_metatile

  CMP #$00
  BEQ position_valid
  CMP #$03
  BEQ position_valid

  JSR lfsr_tick
  JMP search_loop

position_valid:
  LDA respawn_x
  ASL A
  ASL A
  ASL A
  ASL A
  STA collectable_x

  LDA respawn_y
  ASL A
  ASL A
  ASL A
  ASL A
  STA collectable_y

  LDA #$01
  STA collectable_active
  RTS

use_fallback:
  JSR lfsr_tick
  AND #$0F
  CMP #num_safe
  BCC valid_index
  AND #$07
valid_index:
  ASL A
  TAX
  LDA safe_positions, X
  STA collectable_x
  LDA safe_positions+1, X
  STA collectable_y
  LDA #$01
  STA collectable_active
  RTS
.endproc

; ============================================================
; Safe position fallback table (pixel coords = metatile × 16)
; ============================================================
safe_positions:
  .byte $50, $50
  .byte $70, $50
  .byte $90, $50
  .byte $B0, $50
  .byte $50, $70
  .byte $70, $70
  .byte $90, $70
  .byte $B0, $70
  .byte $50, $90
  .byte $70, $90
  .byte $90, $90
  .byte $B0, $90
  .byte $50, $B0
  .byte $70, $B0
  .byte $90, $B0
  .byte $B0, $B0
num_safe = 16

; ============================================================
; Update coin
; ============================================================
.proc update_collectable
  LDA collectable_active
  CMP #$01
  BNE coin_inactive

  ; |player_x - collectable_x| < 16
  LDA player_x
  SEC
  SBC collectable_x
  BCS x_diff
  EOR #$FF
  CLC
  ADC #$01
x_diff:
  CMP #$10
  BCS update_animation

  ; |player_y - collectable_y| < 16
  LDA player_y
  SEC
  SBC collectable_y
  BCS y_diff
  EOR #$FF
  CLC
  ADC #$01
y_diff:
  CMP #$10
  BCS update_animation

collect_item:
  ; Key = win
  LDA key_mode
  CMP #$01
  BEQ collect_key

  LDA diamond_mode
  CMP #$01
  BNE collect_coin

collect_diamond:
  ; +7 points (16-bit safe)
  LDA player_score
  CLC
  ADC #7
  STA player_score
  BCC no_overflow_diamond
  INC player_score+1
no_overflow_diamond:
  LDA #$00
  STA diamond_mode
  ; Speed up (max 3)
  LDA speed_bonus
  CMP #$03
  BEQ after_collect
  INC speed_bonus

  ; Reset timers to avoid freezing when changing threshold
  LDA #$00
  STA enemy_move_timer
  STA enemy2_move_timer
  STA enemy_anim_timer
  STA enemy2_anim_timer
  JMP after_collect

collect_key:
  ; Player collected the key — trigger win condition
  LDA #$00
  STA collectable_active  ; hide the key
  LDA #$01
  STA game_won            ; signal win to main loop and hud
  RTS

collect_coin:
  ; +3 points (16-bit safe)
  LDA player_score
  CLC
  ADC #3
  STA player_score
  BCC no_overflow_coin
  INC player_score+1
no_overflow_coin:
  INC coin_count      ; Track toward next diamond

after_collect:
  JSR decide_next_spawn
  JSR lfsr_tick
  JSR lfsr_tick
  JSR lfsr_tick
  JSR respawn_coin
  RTS

coin_inactive:
  RTS

; --- Ping-pong animation ---
update_animation:
  INC collectable_anim_timer
  LDA collectable_anim_timer
  CMP #$0C
  BNE skip_anim
  LDA #$00
  STA collectable_anim_timer

  LDA collectable_dir
  BNE anim_going_down

  ; Going up: 0 → 1 → 2, change direction when already at 2
  LDA collectable_frame
  CMP #$02
  BEQ set_dir_down
  INC collectable_frame
  JMP skip_anim

set_dir_down:
  LDA #$01
  STA collectable_dir
  JMP skip_anim

anim_going_down:
  ; Going down: 2 → 1 → 0, change direction when already at 0
  LDA collectable_frame
  CMP #$00
  BEQ set_dir_up
  DEC collectable_frame
  JMP skip_anim

set_dir_up:
  LDA #$00
  STA collectable_dir

skip_anim:
  JSR lfsr_tick
  RTS
.endproc

; ============================================================
; Draw coin
; ============================================================
.proc draw_collectable
  LDA collectable_active
  CMP #$01
  BEQ draw_it

  LDA #$FF
  STA $0230
  STA $0234
  STA $0238
  STA $023c
  RTS

draw_it:
  LDA key_mode
  CMP #$01
  BNE not_key
  JMP draw_key
not_key:

  LDA diamond_mode
  CMP #$01
  BNE not_diamond
  JMP draw_diamond
not_diamond:
  JMP draw_normal_coin

; ------------------------------------------------------------
draw_key:
  ; Key with 3 animated frames (ping-pong)
  ; Frame 0: tiles $51,$52,$53,$54
  ; Frame 1: tiles $98,$99,$9A,$9B
  ; Frame 2: tiles $9C,$9D,$9E,$9F

  LDA collectable_frame
  CMP #$00
  BEQ key_frame0
  CMP #$01
  BEQ key_frame1
  ; Frame 2
  LDA #$9C
  STA tile_base
  JMP draw_key_sprites

key_frame0:
  LDA #$51
  STA tile_base
  JMP draw_key_sprites

key_frame1:
  LDA #$98
  STA tile_base
  ; fall through into draw_key_sprites

draw_key_sprites:
  LDA #%00000000     ; Palette 0
  STA attr_base

  LDA collectable_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA temp
  STA $0230
  LDA tile_base
  STA $0231
  LDA attr_base
  STA $0232
  LDA collectable_x
  STA $0233

  LDA temp
  STA $0234
  LDA tile_base
  CLC
  ADC #$01
  STA $0235
  LDA attr_base
  STA $0236
  LDA collectable_x
  CLC
  ADC #$08
  STA $0237

  LDA ppu_lo
  STA $0238
  LDA tile_base
  CLC
  ADC #$02
  STA $0239
  LDA attr_base
  STA $023a
  LDA collectable_x
  STA $023b

  LDA ppu_lo
  STA $023c
  LDA tile_base
  CLC
  ADC #$03
  STA $023d
  LDA attr_base
  STA $023e
  LDA collectable_x
  CLC
  ADC #$08
  STA $023f
  RTS

; ------------------------------------------------------------
draw_diamond:
  ; Tiles $90-$97 — palette 1, ping-pong animation
  LDA collectable_frame
  CMP #$00
  BEQ diamond_frame0
  CMP #$01
  BEQ diamond_frame1
  JMP diamond_frame2

diamond_frame0:
  LDA #$90
  STA tile_base
  LDA #%00000001
  STA attr_base
  JMP draw_diamond_sprites

diamond_frame1:
  LDA #$94
  STA tile_base
  LDA #%00000001
  STA attr_base
  JMP draw_diamond_sprites

diamond_frame2:
  JMP draw_diamond_frame2

draw_diamond_sprites:
  LDA collectable_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA temp
  STA $0230
  LDA tile_base
  STA $0231
  LDA attr_base
  STA $0232
  LDA collectable_x
  STA $0233

  LDA temp
  STA $0234
  LDA tile_base
  CLC
  ADC #$01
  STA $0235
  LDA attr_base
  STA $0236
  LDA collectable_x
  CLC
  ADC #$08
  STA $0237

  LDA ppu_lo
  STA $0238
  LDA tile_base
  CLC
  ADC #$02
  STA $0239
  LDA attr_base
  STA $023a
  LDA collectable_x
  STA $023b

  LDA ppu_lo
  STA $023c
  LDA tile_base
  CLC
  ADC #$03
  STA $023d
  LDA attr_base
  STA $023e
  LDA collectable_x
  CLC
  ADC #$08
  STA $023f
  RTS

draw_diamond_frame2:
  LDA collectable_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA #%01000001     ; Flip horizontal + palette 1
  STA attr_base

  LDA temp
  STA $0230
  LDA #$91
  STA $0231
  LDA attr_base
  STA $0232
  LDA collectable_x
  STA $0233

  LDA temp
  STA $0234
  LDA #$90
  STA $0235
  LDA attr_base
  STA $0236
  LDA collectable_x
  CLC
  ADC #$08
  STA $0237

  LDA ppu_lo
  STA $0238
  LDA #$93
  STA $0239
  LDA attr_base
  STA $023a
  LDA collectable_x
  STA $023b

  LDA ppu_lo
  STA $023c
  LDA #$92
  STA $023d
  LDA attr_base
  STA $023e
  LDA collectable_x
  CLC
  ADC #$08
  STA $023f
  RTS

; ------------------------------------------------------------
draw_normal_coin:
  ; Tiles $49-$50 — palette 2, ping-pong animation
  LDA collectable_frame
  CMP #$00
  BEQ use_frame0
  CMP #$01
  BEQ use_frame1
  JMP use_frame2

use_frame0:
  LDA #$49
  STA tile_base
  LDA #%00000010
  STA attr_base
  JMP draw_sprites_normal

use_frame1:
  LDA #$4D
  STA tile_base
  LDA #%00000010
  STA attr_base
  JMP draw_sprites_normal

use_frame2:
  JMP draw_sprites_frame2

draw_sprites_normal:
  LDA collectable_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA temp
  STA $0230
  LDA tile_base
  STA $0231
  LDA attr_base
  STA $0232
  LDA collectable_x
  STA $0233

  LDA temp
  STA $0234
  LDA tile_base
  CLC
  ADC #$01
  STA $0235
  LDA attr_base
  STA $0236
  LDA collectable_x
  CLC
  ADC #$08
  STA $0237

  LDA ppu_lo
  STA $0238
  LDA tile_base
  CLC
  ADC #$02
  STA $0239
  LDA attr_base
  STA $023a
  LDA collectable_x
  STA $023b

  LDA ppu_lo
  STA $023c
  LDA tile_base
  CLC
  ADC #$03
  STA $023d
  LDA attr_base
  STA $023e
  LDA collectable_x
  CLC
  ADC #$08
  STA $023f
  RTS

draw_sprites_frame2:
  LDA collectable_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA #%01000010
  STA attr_base

  LDA temp
  STA $0230
  LDA #$4A
  STA $0231
  LDA attr_base
  STA $0232
  LDA collectable_x
  STA $0233

  LDA temp
  STA $0234
  LDA #$49
  STA $0235
  LDA attr_base
  STA $0236
  LDA collectable_x
  CLC
  ADC #$08
  STA $0237

  LDA ppu_lo
  STA $0238
  LDA #$4C
  STA $0239
  LDA attr_base
  STA $023a
  LDA collectable_x
  STA $023b

  LDA ppu_lo
  STA $023c
  LDA #$4B
  STA $023d
  LDA attr_base
  STA $023e
  LDA collectable_x
  CLC
  ADC #$08
  STA $023f
  RTS
.endproc